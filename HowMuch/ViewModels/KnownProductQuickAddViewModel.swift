import Foundation
import Observation

@Observable
@MainActor
final class KnownProductQuickAddViewModel {
    private let catalogService: any CatalogServicing
    let locationService: any LocationServicing

    private(set) var product: ProductDetail
    var recentStores: [String] = []
    var errorMessage: String?
    var isSaving = false

    var priceText = ""
    var currencyCode: String
    var storeName = ""
    var quantityText = ""
    var purchasedAt: Date = .now

    var capturedLocation: CapturedLocation?
    var isCapturingLocation = false

    init(
        product: ProductDetail,
        catalogService: any CatalogServicing,
        locationService: any LocationServicing
    ) {
        self.product = product
        self.catalogService = catalogService
        self.locationService = locationService
        self.currencyCode = product.latestEntry?.currencyCode ?? "ZAR"
    }

    var historySnapshot: PriceHistorySnapshot {
        PriceHistoryCalculator.snapshot(for: product.entries)
    }

    var cheapestPlacesSnapshot: CheapestPlacesSnapshot {
        CheapestPlacesCalculator.snapshot(for: product.entries)
    }

    var canSave: Bool {
        priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func loadSupportingData() {
        recentStores = (try? catalogService.recentStores(limit: 6)) ?? []
    }

    func captureLocationIfPossible(force: Bool = false) async {
        if force {
            capturedLocation = nil
        } else if capturedLocation != nil {
            return
        }

        guard isCapturingLocation == false else {
            return
        }

        isCapturingLocation = true
        capturedLocation = await locationService.captureCurrent()
        isCapturingLocation = false
    }

    func clearLocation() {
        capturedLocation = nil
    }

    func save() -> ProductDetail? {
        isSaving = true
        defer { isSaving = false }

        do {
            let amount = try DecimalParser.parseCurrencyInput(priceText)
            let updated = try catalogService.addPriceEntry(
                to: product.id,
                draft: PriceEntryDraft(
                    amount: amount,
                    currencyCode: currencyCode,
                    storeName: storeName,
                    quantityText: quantityText,
                    purchasedAt: purchasedAt,
                    latitude: capturedLocation?.latitude,
                    longitude: capturedLocation?.longitude,
                    placeName: capturedLocation?.placeName
                )
            )

            product = updated
            recentStores = try catalogService.recentStores(limit: 6)
            errorMessage = nil
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
