import Foundation

@MainActor
protocol CatalogServicing {
    func loadProducts(query: String, sort: ProductSortOption) throws -> [ProductSummary]
    func loadProduct(id: UUID) throws -> ProductDetail
    func resolveScan(_ barcode: ScannedBarcode) throws -> ScanResolution
    func saveNewProduct(_ draft: ProductDraft, initialPriceEntry: PriceEntryDraft) throws -> ProductDetail
    func updateProduct(_ draft: ProductUpdateDraft) throws -> ProductDetail
    func deleteProduct(id: UUID) throws
    func addPriceEntry(to productID: UUID, draft: PriceEntryDraft) throws -> ProductDetail
    func updatePriceEntry(_ draft: PriceEntryUpdateDraft) throws -> ProductDetail
    func deletePriceEntry(id: UUID) throws -> ProductDetail
    func recentStores(limit: Int) throws -> [String]
}

@MainActor
final class CatalogService: CatalogServicing {
    private let repository: any CatalogRepository

    init(repository: any CatalogRepository) {
        self.repository = repository
    }

    func loadProducts(query: String, sort: ProductSortOption) throws -> [ProductSummary] {
        try repository.fetchProducts(query: query, sort: sort)
    }

    func loadProduct(id: UUID) throws -> ProductDetail {
        guard let product = try repository.fetchProduct(id: id) else {
            throw CatalogError.productNotFound
        }
        return product
    }

    func resolveScan(_ barcode: ScannedBarcode) throws -> ScanResolution {
        let normalizedBarcode = try BarcodeNormalizer.validated(barcode.payload)

        if let existing = try repository.touchProduct(barcodeValue: normalizedBarcode, scannedAt: barcode.scannedAt) {
            return .existing(existing)
        }

        return .newDraft(
            ProductDraft(
                barcodeValue: normalizedBarcode,
                barcodeType: barcode.symbology
            )
        )
    }

    func saveNewProduct(_ draft: ProductDraft, initialPriceEntry: PriceEntryDraft) throws -> ProductDetail {
        let barcode = try BarcodeNormalizer.validated(draft.barcodeValue)

        if let existing = try repository.fetchProduct(barcodeValue: barcode) {
            return try repository.addPriceEntry(to: existing.id, draft: initialPriceEntry)
        }

        return try repository.createProduct(
            ProductDraft(
                barcodeValue: barcode,
                barcodeType: draft.barcodeType,
                customName: draft.customName,
                brand: draft.brand
            ),
            initialEntry: initialPriceEntry
        )
    }

    func updateProduct(_ draft: ProductUpdateDraft) throws -> ProductDetail {
        try repository.updateProduct(draft)
    }

    func deleteProduct(id: UUID) throws {
        try repository.deleteProduct(id: id)
    }

    func addPriceEntry(to productID: UUID, draft: PriceEntryDraft) throws -> ProductDetail {
        try repository.addPriceEntry(to: productID, draft: draft)
    }

    func updatePriceEntry(_ draft: PriceEntryUpdateDraft) throws -> ProductDetail {
        try repository.updatePriceEntry(draft)
    }

    func deletePriceEntry(id: UUID) throws -> ProductDetail {
        let productID = try repository.deletePriceEntry(id: id)
        return try loadProduct(id: productID)
    }

    func recentStores(limit: Int) throws -> [String] {
        try repository.recentStores(limit: limit)
    }
}
