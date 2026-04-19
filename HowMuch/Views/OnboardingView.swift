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

    @State private var heroAppeared = false
    @State private var featuresAppeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layered background — deep teal → cool blue with a soft glow
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.32, blue: 0.42),
                        Color(red: 0.06, green: 0.46, blue: 0.55),
                        Color(red: 0.10, green: 0.62, blue: 0.50)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Subtle glow behind the hero
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 380, height: 380)
                    .blur(radius: 80)
                    .offset(x: -20, y: -geometry.size.height * 0.22)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 36) {
                        hero
                            .opacity(heroAppeared ? 1 : 0)
                            .offset(y: heroAppeared ? 0 : 14)
                            .animation(.easeOut(duration: 0.55), value: heroAppeared)

                        featureList
                            .opacity(featuresAppeared ? 1 : 0)
                            .offset(y: featuresAppeared ? 0 : 18)
                            .animation(.easeOut(duration: 0.55).delay(0.15), value: featuresAppeared)
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .padding(.top, max(geometry.safeAreaInsets.top + 24, 40))
                    .padding(.bottom, 160)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Haptics.medium()
                        onContinue()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Start Saving Prices")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(Color(red: 0.04, green: 0.30, blue: 0.36))
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white, Color.white.opacity(0.92)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
                    }
                    .buttonStyle(PressableScaleButtonStyle())

                    Text("Takes a few seconds — you'll only see this once.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 14))
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .onAppear {
            heroAppeared = true
            featuresAppeared = true
        }
    }

    private var hero: some View {
        VStack(spacing: 20) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 14)

            VStack(spacing: 10) {
                Text("Last Paid.\nRight when you need it.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("Scan the product. Save the price.\nSee the last amount instantly next time.")
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(2)
            }
        }
    }

    private var featureList: some View {
        VStack(spacing: 12) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(feature.message)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineSpacing(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
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
