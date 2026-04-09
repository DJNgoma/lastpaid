import Foundation
import CoreData

@MainActor
final class AppContainer {
    let persistentContainer: NSPersistentCloudKitContainer
    let catalogService: any CatalogServicing
    let permissionService: any CameraPermissionProviding

    init(
        persistentContainer: NSPersistentCloudKitContainer,
        catalogService: any CatalogServicing,
        permissionService: any CameraPermissionProviding
    ) {
        self.persistentContainer = persistentContainer
        self.catalogService = catalogService
        self.permissionService = permissionService
    }

    static func live() throws -> AppContainer {
        let persistentContainer = try PersistenceController.makePersistentContainer()
        let repository = CoreDataCatalogRepository(context: persistentContainer.viewContext)
        let catalogService = CatalogService(repository: repository)

        return AppContainer(
            persistentContainer: persistentContainer,
            catalogService: catalogService,
            permissionService: CameraPermissionService()
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

    func makeProductDetailViewModel(productID: UUID) -> ProductDetailViewModel {
        ProductDetailViewModel(productID: productID, catalogService: catalogService)
    }
}
