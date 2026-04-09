import Foundation

@MainActor
protocol CatalogRepository {
    func fetchProducts(query: String, sort: ProductSortOption) throws -> [ProductSummary]
    func fetchProduct(id: UUID) throws -> ProductDetail?
    func fetchProduct(barcodeValue: String) throws -> ProductDetail?
    func createProduct(_ draft: ProductDraft, initialEntry: PriceEntryDraft?) throws -> ProductDetail
    func updateProduct(_ draft: ProductUpdateDraft) throws -> ProductDetail
    func deleteProduct(id: UUID) throws
    func addPriceEntry(to productID: UUID, draft: PriceEntryDraft) throws -> ProductDetail
    func updatePriceEntry(_ draft: PriceEntryUpdateDraft) throws -> ProductDetail
    func deletePriceEntry(id: UUID) throws -> UUID
    func touchProduct(barcodeValue: String, scannedAt: Date) throws -> ProductDetail?
    func recentStores(limit: Int) throws -> [String]
}
