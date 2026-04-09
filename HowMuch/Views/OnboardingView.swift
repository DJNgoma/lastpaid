import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    private let features: [OnboardingFeature] = [
        OnboardingFeature(
            title: "Scan the barcode",
            message: "Use the camera when it is convenient, or type the barcode manually if the label is hard to read.",
            systemImage: "barcode.viewfinder"
        ),
        OnboardingFeature(
            title: "Save what you paid",
            message: "Add the price, store, pack size, and purchase date so each product keeps a clean price history.",
            systemImage: "tag"
        ),
        OnboardingFeature(
            title: "Recall the last price fast",
            message: "When you rescan the same product later, the latest price is shown first with the previous one right behind it.",
            systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.28, green: 0.72, blue: 0.95), Color(red: 0.18, green: 0.82, blue: 0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        hero
                        featureList
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .padding(.top, max(geometry.safeAreaInsets.top + 20, 32))
                    .padding(.bottom, 148)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Start Saving Prices")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.05, green: 0.47, blue: 0.41))

                    Text("Onboarding only appears once.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                .background(.thinMaterial)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 22, y: 12)

            VStack(spacing: 8) {
                Text("Remember what you paid.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text("How Much? is built for one fast loop: scan the product, save the price, and see the last amount instantly next time.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.06, green: 0.48, blue: 0.43))
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.95))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(feature.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }
}

private struct OnboardingFeature: Identifiable {
    let title: String
    let message: String
    let systemImage: String

    var id: String { title }
}
