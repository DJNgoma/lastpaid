import Foundation
import CoreData

@MainActor
final class AppContainer {
    let persistentContainer: NSPersistentCloudKitContainer
    let catalogService: any CatalogServicing
    let permissionService: any CameraPermissionProviding
    let locationService: any LocationServicing

    init(
        persistentContainer: NSPersistentCloudKitContainer,
        catalogService: any CatalogServicing,
        permissionService: any CameraPermissionProviding,
        locationService: any LocationServicing
    ) {
        self.persistentContainer = persistentContainer
        self.catalogService = catalogService
        self.permissionService = permissionService
        self.locationService = locationService
    }

    static func live() throws -> AppContainer {
        let persistentContainer = try PersistenceController.makePersistentContainer()
        let repository = CoreDataCatalogRepository(context: persistentContainer.viewContext)
        let catalogService = CatalogService(repository: repository)

        return AppContainer(
            persistentContainer: persistentContainer,
            catalogService: catalogService,
            permissionService: CameraPermissionService(),
            locationService: LocationService()
        )
    }

    func makeCatalogListViewModel() -> CatalogListViewModel {
        CatalogListViewModel(catalogService: catalogService)
    }

    func makeScannerViewModel() -> ScannerViewModel {
        ScannerViewModel(
            catalogService: catalogService,
            permissionService: permissionService,
            scannerService: BarcodeScannerService()
        )
    }

    func makeProductCaptureViewModel(initialDraft: ProductDraft) -> ProductCaptureViewModel {
        ProductCaptureViewModel(
            initialDraft: initialDraft,
            catalogService: catalogService,
            locationService: locationService
        )
    }

    func makeProductDetailViewModel(productID: UUID) -> ProductDetailViewModel {
        ProductDetailViewModel(
            productID: productID,
            catalogService: catalogService,
            locationService: locationService
        )
    }

    func makeKnownProductQuickAddViewModel(product: ProductDetail) -> KnownProductQuickAddViewModel {
        KnownProductQuickAddViewModel(
            product: product,
            catalogService: catalogService,
            locationService: locationService
        )
    }
}
