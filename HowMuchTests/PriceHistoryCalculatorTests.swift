import XCTest

final class PriceHistoryCalculatorTests: XCTestCase {
    func testDifferenceCalculationUsesLatestAndPreviousEntries() {
        let entries = [
            makeEntry(id: UUID(), amount: decimal("49.99"), purchasedAt: date("2026-04-09")),
            makeEntry(id: UUID(), amount: decimal("44.99"), purchasedAt: date("2026-03-01"))
        ]

        let snapshot = PriceHistoryCalculator.snapshot(for: entries)

        XCTAssertEqual(snapshot.latest?.amount, decimal("49.99"))
        XCTAssertEqual(snapshot.previous?.amount, decimal("44.99"))
        XCTAssertEqual(snapshot.difference, decimal("5.00"))
    }

    func testDifferenceIsNilWithSingleEntry() {
        let snapshot = PriceHistoryCalculator.snapshot(
            for: [makeEntry(id: UUID(), amount: decimal("19.99"), purchasedAt: date("2026-04-09"))]
        )

        XCTAssertNil(snapshot.previous)
        XCTAssertNil(snapshot.difference)
    }

    private func makeEntry(id: UUID, amount: Decimal, purchasedAt: Date) -> PriceEntryRecord {
        PriceEntryRecord(
            id: id,
            productID: UUID(),
            amount: amount,
            currencyCode: "ZAR",
            storeName: nil,
            quantityText: nil,
            notes: nil,
            purchasedAt: purchasedAt,
            createdAt: purchasedAt,
            updatedAt: purchasedAt
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
