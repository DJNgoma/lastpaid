import XCTest

final class CheapestPlacesCalculatorTests: XCTestCase {
    func testDuplicateEntriesUseBestRecordedPricePerStore() {
        let snapshot = CheapestPlacesCalculator.snapshot(
            for: [
                makeEntry(amount: "13.99", storeName: "Store A", quantityText: "1L", purchasedAt: "2026-04-10"),
                makeEntry(amount: "9.99", storeName: "Store A", quantityText: "1L", purchasedAt: "2026-03-01"),
                makeEntry(amount: "11.49", storeName: "Store B", quantityText: "1L", purchasedAt: "2026-04-09")
            ]
        )

        XCTAssertEqual(snapshot.places.map(\.label), ["Store A", "Store B"])
        XCTAssertEqual(snapshot.places.map(\.amount), [decimal("9.99"), decimal("11.49")])
        XCTAssertTrue(snapshot.usesEnteredQuantities)
    }

    func testSnapshotKeepsFewerThanThreePlaces() {
        let snapshot = CheapestPlacesCalculator.snapshot(
            for: [
                makeEntry(amount: "15.00", storeName: "Store A", purchasedAt: "2026-04-10"),
                makeEntry(amount: "12.00", storeName: "Store B", purchasedAt: "2026-04-09")
            ]
        )

        XCTAssertEqual(snapshot.places.count, 2)
    }

    func testPlaceNameFallbackAndUnnamedEntryOmission() {
        let snapshot = CheapestPlacesCalculator.snapshot(
            for: [
                makeEntry(amount: "20.00", placeName: "Sandton City", purchasedAt: "2026-04-10"),
                makeEntry(amount: "10.00", purchasedAt: "2026-04-09")
            ]
        )

        XCTAssertEqual(snapshot.places.map(\.label), ["Sandton City"])
        XCTAssertEqual(snapshot.places.first?.sourceKind, .taggedPlace)
    }

    func testTieBreakingFallsBackToAlphabeticalWhenAmountAndDateMatch() {
        let snapshot = CheapestPlacesCalculator.snapshot(
            for: [
                makeEntry(amount: "10.00", storeName: "Bravo Market", purchasedAt: "2026-04-10"),
                makeEntry(amount: "10.00", storeName: "Alpha Foods", purchasedAt: "2026-04-10")
            ]
        )

        XCTAssertEqual(snapshot.places.map(\.label), ["Alpha Foods", "Bravo Market"])
    }

    func testMixedCurrencyEntriesAreExcludedFromComparison() {
        let snapshot = CheapestPlacesCalculator.snapshot(
            for: [
                makeEntry(amount: "12.00", currencyCode: "ZAR", storeName: "Store A", purchasedAt: "2026-04-10"),
                makeEntry(amount: "1.00", currencyCode: "USD", storeName: "Store B", purchasedAt: "2026-04-09")
            ]
        )

        XCTAssertEqual(snapshot.comparedCurrencyCode, "ZAR")
        XCTAssertEqual(snapshot.places.map(\.label), ["Store A"])
    }

    private func makeEntry(
        amount: String,
        currencyCode: String = "ZAR",
        storeName: String? = nil,
        placeName: String? = nil,
        quantityText: String? = nil,
        purchasedAt: String
    ) -> PriceEntryRecord {
        let date = date(purchasedAt)
        return PriceEntryRecord(
            id: UUID(),
            productID: UUID(),
            amount: decimal(amount),
            currencyCode: currencyCode,
            storeName: storeName,
            quantityText: quantityText,
            notes: nil,
            purchasedAt: date,
            createdAt: date,
            updatedAt: date,
            latitude: nil,
            longitude: nil,
            placeName: placeName
        )
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: value)!
    }
}
