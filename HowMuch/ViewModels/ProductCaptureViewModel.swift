import Foundation
import Observation

@Observable
@MainActor
final class ProductCaptureViewModel {
    private let catalogService: any CatalogServicing

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

    init(initialDraft: ProductDraft, catalogService: any CatalogServicing) {
        self.catalogService = catalogService
        self.barcodeValue = initialDraft.barcodeValue
        self.barcodeType = initialDraft.barcodeType
        self.customName = initialDraft.customName
        self.brand = initialDraft.brand ?? ""
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
                    purchasedAt: purchasedAt
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
