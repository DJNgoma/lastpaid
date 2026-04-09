import SwiftUI

@main
struct HowMuchApp: App {
    private let container: AppContainer

    init() {
        do {
            container = try AppContainer.live()
        } catch {
            fatalError("Failed to create app container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            CatalogRootView(container: container)
        }
    }
}
