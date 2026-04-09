import Foundation

struct PriceEntryRecord: Identifiable, Equatable, Sendable, Hashable {
    let id: UUID
    let productID: UUID
    let amount: Decimal
    let currencyCode: String
    let storeName: String?
    let quantityText: String?
    let notes: String?
    let purchasedAt: Date
    let createdAt: Date
    let updatedAt: Date
    let latitude: Double?
    let longitude: Double?
    let placeName: String?

    init(
        id: UUID,
        productID: UUID,
        amount: Decimal,
        currencyCode: String,
        storeName: String?,
        quantityText: String?,
        notes: String?,
        purchasedAt: Date,
        createdAt: Date,
        updatedAt: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil
    ) {
        self.id = id
        self.productID = productID
        self.amount = amount
        self.currencyCode = currencyCode
        self.storeName = storeName
        self.quantityText = quantityText
        self.notes = notes
        self.purchasedAt = purchasedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
}

struct ProductSummary: Identifiable, Equatable, Sendable, Hashable {
    let id: UUID
    let barcodeValue: String
    let barcodeType: BarcodeType
    let customName: String
    let brand: String?
    let latestEntry: PriceEntryRecord?
    let previousEntry: PriceEntryRecord?
    let createdAt: Date
    let updatedAt: Date
    let lastScannedAt: Date

    var displayName: String {
        customName.nilIfBlank ?? barcodeValue
    }
}

struct ProductDetail: Identifiable, Equatable, Sendable {
    let id: UUID
    let barcodeValue: String
    let barcodeType: BarcodeType
    let customName: String
    let brand: String?
    let createdAt: Date
    let updatedAt: Date
    let lastScannedAt: Date
    let entries: [PriceEntryRecord]

    var displayName: String {
        customName.nilIfBlank ?? barcodeValue
    }

    var latestEntry: PriceEntryRecord? { entries.first }
    var previousEntry: PriceEntryRecord? { entries.dropFirst().first }
}

enum ScanResolution: Equatable, Sendable {
    case existing(ProductDetail)
    case newDraft(ProductDraft)
}
