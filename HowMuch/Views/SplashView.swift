import SwiftUI

struct SplashView: View {
    var animateIn: Bool

    var body: some View {
        ZStack {
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

            // Soft glow behind the mark
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .scaleEffect(animateIn ? 1.0 : 0.6)
                .opacity(animateIn ? 1 : 0)

            VStack(spacing: 18) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 14)
                    .scaleEffect(animateIn ? 1.0 : 0.82)
                    .opacity(animateIn ? 1 : 0)

                Text("Last Paid")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
            }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.78), value: animateIn)
    }
}

#Preview {
    SplashView(animateIn: true)
}
