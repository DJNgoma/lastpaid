import Foundation
import Observation

@Observable
@MainActor
final class ProductDetailViewModel {
    private let catalogService: any CatalogServicing

    let productID: UUID
    var product: ProductDetail?
    var recentStores: [String] = []
    var errorMessage: String?
    var isLoading = false

    init(productID: UUID, catalogService: any CatalogServicing) {
        self.productID = productID
        self.catalogService = catalogService
    }

    var historySnapshot: PriceHistorySnapshot {
        PriceHistoryCalculator.snapshot(for: product?.entries ?? [])
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            product = try catalogService.loadProduct(id: productID)
            recentStores = try catalogService.recentStores(limit: 6)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func updateProduct(_ draft: ProductUpdateDraft) -> Bool {
        performMutation {
            try catalogService.updateProduct(draft)
        }
    }

    @discardableResult
    func addPriceEntry(_ draft: PriceEntryDraft) -> Bool {
        performMutation {
            try catalogService.addPriceEntry(to: productID, draft: draft)
        }
    }

    @discardableResult
    func updatePriceEntry(_ draft: PriceEntryUpdateDraft) -> Bool {
        performMutation {
            try catalogService.updatePriceEntry(draft)
        }
    }

    @discardableResult
    func deletePriceEntry(id: UUID) -> Bool {
        performMutation {
            try catalogService.deletePriceEntry(id: id)
        }
    }

    @discardableResult
    func deleteProduct() -> Bool {
        do {
            try catalogService.deleteProduct(id: productID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    @discardableResult
    private func performMutation(_ mutation: () throws -> ProductDetail) -> Bool {
        do {
            product = try mutation()
            recentStores = try catalogService.recentStores(limit: 6)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
