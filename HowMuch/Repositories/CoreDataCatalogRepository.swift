import CoreData
import Foundation

@MainActor
final class CoreDataCatalogRepository: CatalogRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchProducts(query: String, sort: ProductSortOption) throws -> [ProductSummary] {
        let products = try fetchAllProducts()
        let filteredProducts = filter(products: products, query: query)
        let sortedProducts = sortProducts(filteredProducts, sort: sort)

        return sortedProducts.map(makeProductSummary)
    }

    func fetchProduct(id: UUID) throws -> ProductDetail? {
        guard let product = try fetchProductModel(id: id) else {
            return nil
        }
        return makeProductDetail(product)
    }

    func fetchProduct(barcodeValue: String) throws -> ProductDetail? {
        let barcode = BarcodeNormalizer.normalize(barcodeValue)
        guard let product = try fetchProductModel(barcodeValue: barcode) else {
            return nil
        }
        return makeProductDetail(product)
    }

    func createProduct(_ draft: ProductDraft, initialEntry: PriceEntryDraft?) throws -> ProductDetail {
        let barcode = try BarcodeNormalizer.validated(draft.barcodeValue)
        try validateCurrencyCodeIfNeeded(initialEntry?.currencyCode)

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

        try save()
        return makeProductDetail(product)
    }

    func updateProduct(_ draft: ProductUpdateDraft) throws -> ProductDetail {
        let barcode = try BarcodeNormalizer.validated(draft.barcodeValue)
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

        try save()
        return makeProductDetail(product)
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

        return makeProductDetail(product)
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
        return makeProductDetail(product)
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

        return makeProductDetail(product)
    }

    func recentStores(limit: Int) throws -> [String] {
        let request = PriceEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "purchasedAt", ascending: false)]
        let entries = try context.fetch(request)

        var seen = Set<String>()
        var stores: [String] = []

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

        return stores
    }

    private func fetchAllProducts() throws -> [Product] {
        try context.fetch(Product.fetchRequest())
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

    private func filter(products: [Product], query: String) -> [Product] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return products
        }

        return products.filter { product in
            if product.displayName.localizedCaseInsensitiveContains(trimmedQuery) {
                return true
            }
            if product.barcodeValue.localizedCaseInsensitiveContains(trimmedQuery) {
                return true
            }
            if product.brand?.localizedCaseInsensitiveContains(trimmedQuery) == true {
                return true
            }
            return product.priceEntries.contains { entry in
                entry.storeName?.localizedCaseInsensitiveContains(trimmedQuery) == true
            }
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

    private func makeProductSummary(_ product: Product) -> ProductSummary {
        let entries = sortedRecords(for: product)

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

    private func makeProductDetail(_ product: Product) -> ProductDetail {
        ProductDetail(
            id: product.id,
            barcodeValue: product.barcodeValue,
            barcodeType: product.barcodeType,
            customName: product.customName,
            brand: product.brand,
            createdAt: product.createdAt,
            updatedAt: product.updatedAt,
            lastScannedAt: product.lastScannedAt,
            entries: sortedRecords(for: product)
        )
    }

    private func sortedRecords(for product: Product) -> [PriceEntryRecord] {
        product.priceEntries
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
                    amount: entry.amount,
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

    private func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
