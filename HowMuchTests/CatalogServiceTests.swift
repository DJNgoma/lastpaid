import XCTest

@MainActor
final class CatalogServiceTests: XCTestCase {
    func testProductCreationPersistsInitialEntry() throws {
        let service = try makeSUT()

        let detail = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "6001234567890",
                barcodeType: .ean13,
                customName: "Full Cream Milk",
                brand: "Clover"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("49.99"),
                currencyCode: "ZAR",
                storeName: "Checkers",
                quantityText: "2L",
                purchasedAt: date("2026-04-09")
            )
        )

        XCTAssertEqual(detail.barcodeValue, "6001234567890")
        XCTAssertEqual(detail.customName, "Full Cream Milk")
        XCTAssertEqual(detail.entries.count, 1)
        XCTAssertEqual(detail.latestEntry?.amount, decimal("49.99"))
        XCTAssertEqual(detail.latestEntry?.storeName, "Checkers")
    }

    func testAddingMultiplePriceEntriesReturnsHistoryDescending() throws {
        let service = try makeSUT()
        let created = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "4006381333931",
                barcodeType: .ean13,
                customName: "Corn Flakes"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("54.99"),
                purchasedAt: date("2026-03-01")
            )
        )

        _ = try service.addPriceEntry(
            to: created.id,
            draft: PriceEntryDraft(
                amount: decimal("57.99"),
                storeName: "Pick n Pay",
                purchasedAt: date("2026-04-01")
            )
        )

        let detail = try service.addPriceEntry(
            to: created.id,
            draft: PriceEntryDraft(
                amount: decimal("59.99"),
                storeName: "Woolworths",
                purchasedAt: date("2026-04-05")
            )
        )

        XCTAssertEqual(detail.entries.map(\.amount), [decimal("59.99"), decimal("57.99"), decimal("54.99")])
        XCTAssertEqual(detail.latestEntry?.storeName, "Woolworths")
        XCTAssertEqual(detail.previousEntry?.storeName, "Pick n Pay")
    }

    func testLookupByBarcodeReturnsExistingProduct() throws {
        let service = try makeSUT()
        let created = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "012345678905",
                barcodeType: .upca,
                customName: "Peanut Butter"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("89.99"),
                storeName: "Spar"
            )
        )

        let resolution = try service.resolveScan(
            ScannedBarcode(payload: "012345678905", symbology: .upca, scannedAt: date("2026-04-09"))
        )

        guard case .existing(let detail) = resolution else {
            return XCTFail("Expected an existing product resolution")
        }

        XCTAssertEqual(detail.id, created.id)
        XCTAssertEqual(detail.displayName, "Peanut Butter")
    }

    func testLatestPriceRetrievalUsesMostRecentPurchaseDate() throws {
        let service = try makeSUT()
        let created = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "12345670",
                barcodeType: .ean8,
                customName: "Chocolate"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("14.99"),
                purchasedAt: date("2026-01-10")
            )
        )

        _ = try service.addPriceEntry(
            to: created.id,
            draft: PriceEntryDraft(
                amount: decimal("16.99"),
                purchasedAt: date("2026-02-10")
            )
        )

        let products = try service.loadProducts(query: "Chocolate", sort: .recentlyUpdated)

        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.latestEntry?.amount, decimal("16.99"))
        XCTAssertEqual(products.first?.previousEntry?.amount, decimal("14.99"))
    }

    func testUpdateAndDeleteFlows() throws {
        let service = try makeSUT()
        let created = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "5012345678900",
                barcodeType: .ean13,
                customName: "Yoghurt"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("24.99"),
                storeName: "Shoprite",
                purchasedAt: date("2026-03-20")
            )
        )

        let renamed = try service.updateProduct(
            ProductUpdateDraft(
                productID: created.id,
                barcodeValue: "5012345678900",
                barcodeType: .ean13,
                customName: "Greek Yoghurt",
                brand: "Nola"
            )
        )

        XCTAssertEqual(renamed.customName, "Greek Yoghurt")
        XCTAssertEqual(renamed.brand, "Nola")

        let withSecondEntry = try service.addPriceEntry(
            to: created.id,
            draft: PriceEntryDraft(
                amount: decimal("27.99"),
                storeName: "Woolworths",
                purchasedAt: date("2026-04-01")
            )
        )

        let originalEntry = withSecondEntry.entries.last!
        let edited = try service.updatePriceEntry(
            PriceEntryUpdateDraft(
                entryID: originalEntry.id,
                productID: created.id,
                amount: decimal("25.99"),
                currencyCode: "ZAR",
                storeName: "Shoprite",
                quantityText: "1kg",
                notes: "Promo shelf",
                purchasedAt: originalEntry.purchasedAt
            )
        )

        XCTAssertEqual(edited.entries.last?.amount, decimal("25.99"))
        XCTAssertEqual(edited.entries.last?.notes, "Promo shelf")

        let afterDeletion = try service.deletePriceEntry(id: edited.latestEntry!.id)
        XCTAssertEqual(afterDeletion.entries.count, 1)
        XCTAssertEqual(afterDeletion.latestEntry?.amount, decimal("25.99"))

        try service.deleteProduct(id: created.id)
        XCTAssertThrowsError(try service.loadProduct(id: created.id)) { error in
            XCTAssertEqual(error as? CatalogError, .productNotFound)
        }
    }

    func testSearchIncludesStoreNames() throws {
        let service = try makeSUT()
        _ = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "9780201379624",
                barcodeType: .ean13,
                customName: "Olive Oil"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("139.95"),
                storeName: "Food Lover's Market"
            )
        )

        let products = try service.loadProducts(query: "Food Lover", sort: .alphabetical)

        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.displayName, "Olive Oil")
    }

    private func makeSUT() throws -> CatalogService {
        let container = try PersistenceController.makePersistentContainer(inMemory: true)
        let repository = CoreDataCatalogRepository(context: container.viewContext)
        return CatalogService(repository: repository)
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
