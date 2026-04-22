import XCTest

final class CatalogScanFlowTests: XCTestCase {
    func testNewBarcodeRoutesToCapture() {
        let draft = ProductDraft(
            barcodeValue: "6001234567890",
            barcodeType: .ean13
        )

        let destination = CatalogScanFlow.destination(
            for: .newDraft(draft),
            knownProductOrigin: .scanner
        )

        XCTAssertEqual(destination, .capture(draft))
    }

    func testKnownBarcodeRoutesToQuickAdd() {
        let product = makeProductDetail()

        let destination = CatalogScanFlow.destination(
            for: .existing(product),
            knownProductOrigin: .manualEntry
        )

        XCTAssertEqual(destination, .quickAdd(product, origin: .manualEntry))
    }

    func testScannerSaveFollowUpReopensScanner() {
        XCTAssertEqual(CatalogScanFlow.saveFollowUp(for: .scanner), .reopenScanner)
    }

    func testManualEntrySaveFollowUpReturnsHome() {
        XCTAssertEqual(CatalogScanFlow.saveFollowUp(for: .manualEntry), .none)
    }

    private func makeProductDetail() -> ProductDetail {
        let now = Date()
        return ProductDetail(
            id: UUID(),
            barcodeValue: "6001234567890",
            barcodeType: .ean13,
            customName: "Milk",
            brand: "Clover",
            createdAt: now,
            updatedAt: now,
            lastScannedAt: now,
            entries: []
        )
    }
}
