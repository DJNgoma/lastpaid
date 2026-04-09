import SwiftUI

@main
struct HowMuchApp: App {
    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
        }
    }
}

private struct AppBootstrapView: View {
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var container: AppContainer?
    @State private var bootstrapError: String?

    var body: some View {
        Group {
            if let container {
                if didCompleteOnboarding {
                    CatalogRootView(
                        viewModel: container.makeCatalogListViewModel(),
                        makeScannerViewModel: { container.makeScannerViewModel() },
                        makeProductCaptureViewModel: { draft in
                            container.makeProductCaptureViewModel(initialDraft: draft)
                        },
                        makeProductDetailViewModel: { productID in
                            container.makeProductDetailViewModel(productID: productID)
                        }
                    )
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            didCompleteOnboarding = true
                        }
                    }
                }
            } else if let bootstrapError {
                ContentUnavailableView(
                    "How Much? Couldn’t Start",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(bootstrapError)
                )
                .overlay(alignment: .bottom) {
                    Button("Retry", action: bootstrap)
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 32)
                }
            } else {
                ProgressView("Loading…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(.systemBackground).ignoresSafeArea())
        .task {
            guard container == nil, bootstrapError == nil else {
                return
            }
            bootstrap()
        }
    }

    private func bootstrap() {
        do {
            container = try AppContainer.live()
            bootstrapError = nil
        } catch {
            container = nil
            bootstrapError = error.localizedDescription
        }
    }
}
