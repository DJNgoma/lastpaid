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
