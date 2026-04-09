import Foundation

struct ProductDraft: Equatable, Sendable, Identifiable {
    let id: UUID
    var barcodeValue: String
    var barcodeType: BarcodeType
    var customName: String
    var brand: String?

    init(
        id: UUID = UUID(),
        barcodeValue: String,
        barcodeType: BarcodeType,
        customName: String = "",
        brand: String? = nil
    ) {
        self.id = id
        self.barcodeValue = BarcodeNormalizer.normalize(barcodeValue, symbology: barcodeType)
        self.barcodeType = barcodeType
        self.customName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.brand = brand?.nilIfBlank
    }
}

struct ProductUpdateDraft: Equatable, Sendable {
    let productID: UUID
    var barcodeValue: String
    var barcodeType: BarcodeType
    var customName: String
    var brand: String?

    init(productID: UUID, barcodeValue: String, barcodeType: BarcodeType, customName: String, brand: String?) {
        self.productID = productID
        self.barcodeValue = BarcodeNormalizer.normalize(barcodeValue, symbology: barcodeType)
        self.barcodeType = barcodeType
        self.customName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.brand = brand?.nilIfBlank
    }
}
