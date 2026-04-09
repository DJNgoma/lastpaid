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
    @State private var splashAnimateIn = false
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            mainContent
                .opacity(splashFinished ? 1 : 0)
                .scaleEffect(splashFinished ? 1 : 0.985)
                .animation(.easeOut(duration: 0.45), value: splashFinished)

            if splashFinished == false {
                SplashView(animateIn: splashAnimateIn)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(.systemBackground).ignoresSafeArea())
        .task {
            await runLaunchSequence()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
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
            Color.clear
        }
    }

    @MainActor
    private func runLaunchSequence() async {
        guard splashFinished == false else { return }

        // Kick off the splash entrance animation immediately.
        splashAnimateIn = true

        // Bootstrap (fast / synchronous) then hold the splash briefly so it's
        // perceptible even on instant cold launches.
        if container == nil, bootstrapError == nil {
            bootstrap()
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        withAnimation(.easeInOut(duration: 0.5)) {
            splashFinished = true
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
