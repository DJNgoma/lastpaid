import CoreData
import Foundation

@MainActor
final class CoreDataCatalogRepository: CatalogRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchProducts(query: String, sort: ProductSortOption) throws -> [ProductSummary] {
        let request = makeProductFetchRequest(query: query, sort: sort)
        let products = try context.fetch(request)
        let sortedProducts = sortProducts(products, sort: sort)

        return try sortedProducts.map(makeProductSummary)
    }

    func fetchProduct(id: UUID) throws -> ProductDetail? {
        guard let product = try fetchProductModel(id: id) else {
            return nil
        }
        return try makeProductDetail(product)
    }

    func fetchProduct(barcodeValue: String) throws -> ProductDetail? {
        let barcode = BarcodeNormalizer.normalize(barcodeValue)
        guard let product = try fetchProductModel(barcodeValue: barcode) else {
            return nil
        }
        return try makeProductDetail(product)
    }

    func createProduct(_ draft: ProductDraft, initialEntry: PriceEntryDraft?) throws -> ProductDetail {
        let barcode = try BarcodeNormalizer.validated(draft.barcodeValue, symbology: draft.barcodeType)
        try validateCurrencyCodeIfNeeded(initialEntry?.currencyCode)
        try validateProductName(draft.customName)

        if try fetchProductModel(barcodeValue: barcode) != nil {
            throw CatalogError.duplicateBarcode(barcode)
        }

        let now = Date.now
        let product = Product(
            context: context,
            barcodeValue: barcode,
            barcodeType: draft.barcodeType,
            customName: draft.customName,
            brand: draft.brand,
            createdAt: now,
            updatedAt: now,
            lastScannedAt: now
        )

        if let initialEntry {
            _ = PriceEntry(
                context: context,
                amount: initialEntry.amount,
                currencyCode: initialEntry.currencyCode,
                storeName: initialEntry.storeName,
                quantityText: initialEntry.quantityText,
                notes: initialEntry.notes,
                purchasedAt: initialEntry.purchasedAt,
                createdAt: now,
                updatedAt: now,
                product: product
            )
        }

        try save(conflictingBarcode: barcode)
        return try makeProductDetail(product)
    }

    func updateProduct(_ draft: ProductUpdateDraft) throws -> ProductDetail {
        let barcode = try BarcodeNormalizer.validated(draft.barcodeValue, symbology: draft.barcodeType)
        try validateProductName(draft.customName)
        guard let product = try fetchProductModel(id: draft.productID) else {
            throw CatalogError.productNotFound
        }

        if let existing = try fetchProductModel(barcodeValue: barcode), existing.id != product.id {
            throw CatalogError.duplicateBarcode(barcode)
        }

        product.barcodeValue = barcode
        product.barcodeType = draft.barcodeType
        product.customName = draft.customName
        product.brand = draft.brand
        product.updatedAt = .now

        try save(conflictingBarcode: barcode)
        return try makeProductDetail(product)
    }

    func deleteProduct(id: UUID) throws {
        guard let product = try fetchProductModel(id: id) else {
            throw CatalogError.productNotFound
        }

        context.delete(product)
        try save()
    }

    func addPriceEntry(to productID: UUID, draft: PriceEntryDraft) throws -> ProductDetail {
        try validateCurrencyCodeIfNeeded(draft.currencyCode)

        guard let product = try fetchProductModel(id: productID) else {
            throw CatalogError.productNotFound
        }

        let now = Date.now
        _ = PriceEntry(
            context: context,
            amount: draft.amount,
            currencyCode: draft.currencyCode,
            storeName: draft.storeName,
            quantityText: draft.quantityText,
            notes: draft.notes,
            purchasedAt: draft.purchasedAt,
            createdAt: now,
            updatedAt: now,
            product: product
        )

        product.updatedAt = now
        try save()

        return try makeProductDetail(product)
    }

    func updatePriceEntry(_ draft: PriceEntryUpdateDraft) throws -> ProductDetail {
        try validateCurrencyCodeIfNeeded(draft.currencyCode)

        guard let entry = try fetchPriceEntryModel(id: draft.entryID),
              let product = entry.product,
              product.id == draft.productID else {
            throw CatalogError.priceEntryNotFound
        }

        let now = Date.now
        entry.amount = draft.amount
        entry.currencyCode = draft.currencyCode
        entry.storeName = draft.storeName
        entry.quantityText = draft.quantityText
        entry.notes = draft.notes
        entry.purchasedAt = draft.purchasedAt
        entry.updatedAt = now
        product.updatedAt = now

        try save()
        return try makeProductDetail(product)
    }

    func deletePriceEntry(id: UUID) throws -> UUID {
        guard let entry = try fetchPriceEntryModel(id: id),
              let product = entry.product else {
            throw CatalogError.priceEntryNotFound
        }

        let productID = product.id
        product.updatedAt = .now
        context.delete(entry)
        try save()

        return productID
    }

    func touchProduct(barcodeValue: String, scannedAt: Date) throws -> ProductDetail? {
        let barcode = BarcodeNormalizer.normalize(barcodeValue)
        guard let product = try fetchProductModel(barcodeValue: barcode) else {
            return nil
        }

        product.lastScannedAt = scannedAt
        try save()

        return try makeProductDetail(product)
    }

    func recentStores(limit: Int) throws -> [String] {
        guard limit > 0 else {
            return []
        }

        var seen = Set<String>()
        var stores: [String] = []
        var offset = 0
        let batchSize = max(limit * 4, 20)

        while stores.count < limit {
            let request = PriceEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "purchasedAt", ascending: false)]
            request.fetchLimit = batchSize
            request.fetchOffset = offset
            request.returnsObjectsAsFaults = false

            let entries = try context.fetch(request)
            guard entries.isEmpty == false else {
                break
            }

            for entry in entries {
                guard let store = entry.storeName?.nilIfBlank else {
                    continue
                }
                if seen.insert(store).inserted {
                    stores.append(store)
                }
                if stores.count == limit {
                    break
                }
            }

            guard entries.count == batchSize else {
                break
            }
            offset += entries.count
        }

        return stores
    }

    private func makeProductFetchRequest(
        query: String,
        sort: ProductSortOption
    ) -> NSFetchRequest<Product> {
        let request = Product.fetchRequest()
        request.predicate = makeSearchPredicate(query: query)
        request.sortDescriptors = makeSortDescriptors(sort: sort)
        request.fetchBatchSize = 50
        request.relationshipKeyPathsForPrefetching = ["priceEntries"]
        request.returnsObjectsAsFaults = false
        return request
    }

    private func fetchProductModel(id: UUID) throws -> Product? {
        let request = Product.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    private func fetchProductModel(barcodeValue: String) throws -> Product? {
        let request = Product.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "barcodeValue == %@", barcodeValue)
        return try context.fetch(request).first
    }

    private func fetchPriceEntryModel(id: UUID) throws -> PriceEntry? {
        let request = PriceEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    private func makeSearchPredicate(query: String) -> NSPredicate? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return nil
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "customName CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(format: "barcodeValue CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(format: "brand CONTAINS[cd] %@", trimmedQuery),
            NSPredicate(
                format: "SUBQUERY(priceEntries, $entry, $entry.storeName CONTAINS[cd] %@).@count > 0",
                trimmedQuery
            )
        ])
    }

    private func makeSortDescriptors(sort: ProductSortOption) -> [NSSortDescriptor] {
        switch sort {
        case .recentlyUpdated:
            return [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "customName", ascending: true)
            ]
        case .recentlyScanned:
            return [
                NSSortDescriptor(key: "lastScannedAt", ascending: false),
                NSSortDescriptor(key: "customName", ascending: true)
            ]
        case .alphabetical:
            return [
                NSSortDescriptor(key: "customName", ascending: true),
                NSSortDescriptor(key: "barcodeValue", ascending: true)
            ]
        }
    }

    private func sortProducts(_ products: [Product], sort: ProductSortOption) -> [Product] {
        switch sort {
        case .recentlyUpdated:
            return products.sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        case .recentlyScanned:
            return products.sorted { lhs, rhs in
                if lhs.lastScannedAt == rhs.lastScannedAt {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.lastScannedAt > rhs.lastScannedAt
            }
        case .alphabetical:
            return products.sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    private func makeProductSummary(_ product: Product) throws -> ProductSummary {
        let entries = try sortedRecords(for: product)

        return ProductSummary(
            id: product.id,
            barcodeValue: product.barcodeValue,
            barcodeType: product.barcodeType,
            customName: product.customName,
            brand: product.brand,
            latestEntry: entries.first,
            previousEntry: entries.dropFirst().first,
            createdAt: product.createdAt,
            updatedAt: product.updatedAt,
            lastScannedAt: product.lastScannedAt
        )
    }

    private func makeProductDetail(_ product: Product) throws -> ProductDetail {
        ProductDetail(
            id: product.id,
            barcodeValue: product.barcodeValue,
            barcodeType: product.barcodeType,
            customName: product.customName,
            brand: product.brand,
            createdAt: product.createdAt,
            updatedAt: product.updatedAt,
            lastScannedAt: product.lastScannedAt,
            entries: try sortedRecords(for: product)
        )
    }

    private func sortedRecords(for product: Product) throws -> [PriceEntryRecord] {
        try product.priceEntries
            .sorted { lhs, rhs in
                if lhs.purchasedAt == rhs.purchasedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.purchasedAt > rhs.purchasedAt
            }
            .map { entry in
                PriceEntryRecord(
                    id: entry.id,
                    productID: product.id,
                    amount: try entry.decodedAmount(),
                    currencyCode: entry.currencyCode,
                    storeName: entry.storeName,
                    quantityText: entry.quantityText,
                    notes: entry.notes,
                    purchasedAt: entry.purchasedAt,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt
                )
            }
    }

    private func validateCurrencyCodeIfNeeded(_ currencyCode: String?) throws {
        guard let currencyCode else {
            return
        }
        guard Locale.commonISOCurrencyCodes.contains(currencyCode) else {
            throw CatalogError.invalidCurrencyCode(currencyCode)
        }
    }

    private func validateProductName(_ customName: String) throws {
        guard customName.nilIfBlank != nil else {
            throw CatalogError.missingProductName
        }
    }

    private func save(conflictingBarcode: String? = nil) throws {
        guard context.hasChanges else {
            return
        }

        do {
            try context.save()
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain,
               error.code == NSManagedObjectConstraintMergeError,
               let conflictingBarcode {
                throw CatalogError.duplicateBarcode(conflictingBarcode)
            }

            throw CatalogError.persistenceFailure(error.localizedDescription)
        }
    }
}
