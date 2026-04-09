import Foundation

struct PriceEntryDraft: Equatable, Sendable {
    var amount: Decimal
    var currencyCode: String
    var storeName: String?
    var quantityText: String?
    var notes: String?
    var purchasedAt: Date
    var latitude: Double?
    var longitude: Double?
    var placeName: String?

    init(
        amount: Decimal,
        currencyCode: String = "ZAR",
        storeName: String? = nil,
        quantityText: String? = nil,
        notes: String? = nil,
        purchasedAt: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil
    ) {
        self.amount = amount
        self.currencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.storeName = storeName?.nilIfBlank
        self.quantityText = quantityText?.nilIfBlank
        self.notes = notes?.nilIfBlank
        self.purchasedAt = purchasedAt
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName?.nilIfBlank
    }
}

struct PriceEntryUpdateDraft: Equatable, Sendable {
    let entryID: UUID
    let productID: UUID
    var amount: Decimal
    var currencyCode: String
    var storeName: String?
    var quantityText: String?
    var notes: String?
    var purchasedAt: Date
    var latitude: Double?
    var longitude: Double?
    var placeName: String?

    init(
        entryID: UUID,
        productID: UUID,
        amount: Decimal,
        currencyCode: String,
        storeName: String?,
        quantityText: String?,
        notes: String?,
        purchasedAt: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil
    ) {
        self.entryID = entryID
        self.productID = productID
        self.amount = amount
        self.currencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.storeName = storeName?.nilIfBlank
        self.quantityText = quantityText?.nilIfBlank
        self.notes = notes?.nilIfBlank
        self.purchasedAt = purchasedAt
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName?.nilIfBlank
    }
}
