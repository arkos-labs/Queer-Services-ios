import SwiftUI

/// Signature animée au lancement, sans indicateur de chargement système.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var rotating = false

    let onIntroFinished: () -> Void

    var body: some View {
        ZStack {
            Color(hex: 0x170B25).ignoresSafeArea()

            RadialGradient(
                colors: [Theme.primary.opacity(0.42), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 270
            )
            .ignoresSafeArea()
            .opacity(revealed ? 1 : 0)

            VStack(spacing: 26) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 138, height: 138)
                    .shadow(color: Theme.primary.opacity(0.28), radius: 28, y: 8)
                    .rotationEffect(.degrees(rotating ? 360 : 0))
                    .animation(
                        reduceMotion ? nil : .linear(duration: 1.6).repeatForever(autoreverses: false),
                        value: rotating
                    )
                    .rotation3DEffect(.degrees(revealed ? 0 : -65), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(revealed ? 1 : 0.65)
                    .opacity(revealed ? 1 : 0)
                    .accessibilityHidden(true)

                Text("Queer Services")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 12)
            }
            .padding(32)
            .accessibilityElement(children: .combine)
        }
        .task {
            if reduceMotion {
                revealed = true
                onIntroFinished()
                return
            }
            rotating = true
            withAnimation(.spring(duration: 0.7, bounce: 0.12)) {
                revealed = true
            }
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            onIntroFinished()
        }
    }
}
