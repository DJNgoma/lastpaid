import CoreLocation
import XCTest

@MainActor
final class KnownProductQuickAddViewModelTests: XCTestCase {
    func testSaveRefreshesLatestPriceAndCheapestPlaces() throws {
        let service = try makeService()
        let created = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "4006381333931",
                barcodeType: .ean13,
                customName: "Full Cream Milk"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("12.00"),
                currencyCode: "ZAR",
                storeName: "Store A",
                quantityText: "1L",
                purchasedAt: date("2026-03-01")
            )
        )

        _ = try service.addPriceEntry(
            to: created.id,
            draft: PriceEntryDraft(
                amount: decimal("11.00"),
                currencyCode: "ZAR",
                storeName: "Store B",
                quantityText: "1L",
                purchasedAt: date("2026-03-10")
            )
        )

        let product = try service.loadProduct(id: created.id)
        let viewModel = KnownProductQuickAddViewModel(
            product: product,
            catalogService: service,
            locationService: TestLocationService()
        )

        viewModel.loadSupportingData()
        viewModel.priceText = "10.50"
        viewModel.storeName = "Store C"
        viewModel.quantityText = "1L"
        viewModel.purchasedAt = date("2026-04-01")
        viewModel.capturedLocation = CapturedLocation(
            latitude: -26.1076,
            longitude: 28.0567,
            placeName: "Sandton City"
        )

        let updated = try XCTUnwrap(viewModel.save())

        XCTAssertEqual(updated.latestEntry?.amount, decimal("10.50"))
        XCTAssertEqual(viewModel.product.latestEntry?.storeName, "Store C")
        XCTAssertEqual(viewModel.product.latestEntry?.placeName, "Sandton City")
        XCTAssertEqual(viewModel.cheapestPlacesSnapshot.places.map(\.label), ["Store C", "Store B", "Store A"])
    }

    func testSaveRefreshesRecentStores() throws {
        let service = try makeService()
        let created = try service.saveNewProduct(
            ProductDraft(
                barcodeValue: "5012345678900",
                barcodeType: .ean13,
                customName: "Yoghurt"
            ),
            initialPriceEntry: PriceEntryDraft(
                amount: decimal("24.99"),
                currencyCode: "ZAR",
                storeName: "Shoprite",
                purchasedAt: date("2026-03-20")
            )
        )

        let product = try service.loadProduct(id: created.id)
        let viewModel = KnownProductQuickAddViewModel(
            product: product,
            catalogService: service,
            locationService: TestLocationService()
        )

        viewModel.loadSupportingData()
        XCTAssertEqual(viewModel.recentStores, ["Shoprite"])

        viewModel.priceText = "22.49"
        viewModel.storeName = "Checkers"
        viewModel.purchasedAt = date("2026-04-01")

        _ = try XCTUnwrap(viewModel.save())

        XCTAssertEqual(viewModel.recentStores.first, "Checkers")
        XCTAssertTrue(viewModel.recentStores.contains("Shoprite"))
    }

    private func makeService() throws -> CatalogService {
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

@MainActor
private final class TestLocationService: LocationServicing {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse

    func captureCurrent() async -> CapturedLocation? {
        nil
    }
}
