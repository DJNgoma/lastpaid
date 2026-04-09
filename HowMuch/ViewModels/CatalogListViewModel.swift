import Foundation
import Observation

@Observable
@MainActor
final class CatalogListViewModel {
    private let catalogService: any CatalogServicing
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    var products: [ProductSummary] = []
    var searchText = ""
    var sortOption: ProductSortOption = .recentlyUpdated
    var errorMessage: String?
    var isLoading = false

    init(catalogService: any CatalogServicing) {
        self.catalogService = catalogService
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        hasLoaded = true
        scheduleLoad(immediate: true)
    }

    func scheduleLoad(immediate: Bool = false) {
        loadTask?.cancel()

        let query = searchText
        let sort = sortOption

        loadTask = Task { [weak self] in
            if immediate == false {
                try? await Task.sleep(for: .milliseconds(250))
            }

            guard let self, Task.isCancelled == false else {
                return
            }

            self.load(query: query, sort: sort)
        }
    }

    func load(query: String? = nil, sort: ProductSortOption? = nil) {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try catalogService.loadProducts(
                query: query ?? searchText,
                sort: sort ?? sortOption
            )
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
            scheduleLoad(immediate: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveManualBarcode(_ barcodeValue: String, type: BarcodeType) -> ScanResolution? {
        do {
            let normalized = try BarcodeNormalizer.validated(barcodeValue, symbology: type)
            errorMessage = nil
            return try catalogService.resolveScan(
                ScannedBarcode(payload: normalized, symbology: type)
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
