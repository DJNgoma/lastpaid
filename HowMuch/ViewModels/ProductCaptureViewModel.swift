import Foundation
import Observation

@Observable
@MainActor
final class ProductCaptureViewModel {
    private let catalogService: any CatalogServicing
    private let locationService: any LocationServicing

    var barcodeValue: String
    var barcodeType: BarcodeType
    var customName: String
    var brand: String
    var priceText = ""
    var currencyCode = "ZAR"
    var storeName = ""
    var quantityText = ""
    var notes = ""
    var purchasedAt: Date = .now
    var recentStores: [String] = []
    var errorMessage: String?
    var isSaving = false

    var capturedLocation: CapturedLocation?
    var isCapturingLocation = false

    init(
        initialDraft: ProductDraft,
        catalogService: any CatalogServicing,
        locationService: any LocationServicing
    ) {
        self.catalogService = catalogService
        self.locationService = locationService
        self.barcodeValue = initialDraft.barcodeValue
        self.barcodeType = initialDraft.barcodeType
        self.customName = initialDraft.customName
        self.brand = initialDraft.brand ?? ""
    }

    func captureLocationIfPossible() async {
        guard capturedLocation == nil, isCapturingLocation == false else { return }
        isCapturingLocation = true
        capturedLocation = await locationService.captureCurrent()
        isCapturingLocation = false
    }

    func clearLocation() {
        capturedLocation = nil
    }

    var canSave: Bool {
        customName.nilIfBlank != nil && priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func loadRecentStores() {
        recentStores = (try? catalogService.recentStores(limit: 6)) ?? []
    }

    func save() -> ProductDetail? {
        isSaving = true
        defer { isSaving = false }

        do {
            let amount = try DecimalParser.parseCurrencyInput(priceText)
            let detail = try catalogService.saveNewProduct(
                ProductDraft(
                    barcodeValue: barcodeValue,
                    barcodeType: barcodeType,
                    customName: customName,
                    brand: brand
                ),
                initialPriceEntry: PriceEntryDraft(
                    amount: amount,
                    currencyCode: currencyCode,
                    storeName: storeName,
                    quantityText: quantityText,
                    notes: notes,
                    purchasedAt: purchasedAt,
                    latitude: capturedLocation?.latitude,
                    longitude: capturedLocation?.longitude,
                    placeName: capturedLocation?.placeName
                )
            )
            errorMessage = nil
            return detail
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
