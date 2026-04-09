import Foundation
import Observation

@Observable
@MainActor
final class CatalogListViewModel {
    private let catalogService: any CatalogServicing

    var products: [ProductSummary] = []
    var searchText = ""
    var sortOption: ProductSortOption = .recentlyUpdated
    var errorMessage: String?
    var isLoading = false

    init(catalogService: any CatalogServicing) {
        self.catalogService = catalogService
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try catalogService.loadProducts(query: searchText, sort: sortOption)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProducts(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            products.indices.contains(index) ? products[index].id : nil
        }

        do {
            for id in ids {
                try catalogService.deleteProduct(id: id)
            }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
