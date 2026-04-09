import Foundation

struct PriceEntryDraft: Equatable, Sendable {
    var amount: Decimal
    var currencyCode: String
    var storeName: String?
    var quantityText: String?
    var notes: String?
    var purchasedAt: Date

    init(
        amount: Decimal,
        currencyCode: String = "ZAR",
        storeName: String? = nil,
        quantityText: String? = nil,
        notes: String? = nil,
        purchasedAt: Date = .now
    ) {
        self.amount = amount
        self.currencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.storeName = storeName?.nilIfBlank
        self.quantityText = quantityText?.nilIfBlank
        self.notes = notes?.nilIfBlank
        self.purchasedAt = purchasedAt
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

    init(
        entryID: UUID,
        productID: UUID,
        amount: Decimal,
        currencyCode: String,
        storeName: String?,
        quantityText: String?,
        notes: String?,
        purchasedAt: Date
    ) {
        self.entryID = entryID
        self.productID = productID
        self.amount = amount
        self.currencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.storeName = storeName?.nilIfBlank
        self.quantityText = quantityText?.nilIfBlank
        self.notes = notes?.nilIfBlank
        self.purchasedAt = purchasedAt
    }
}
