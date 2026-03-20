import SwiftUI

struct SplashView: View {
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.8

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Text("Flume")
                .font(.system(size: 48, weight: .bold))
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onFinished()
            }
        }
    }
}
