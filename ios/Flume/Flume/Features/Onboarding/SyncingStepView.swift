import SwiftUI

struct SyncingStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var elapsed = 0
    @State private var pulseScale = 1.0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            Text("Analyzing Your Finances")
                .font(.title.bold())

            Text("We're syncing your transactions. This usually takes a few seconds.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if elapsed >= 60 {
                Text("This is taking longer than expected. Hang tight...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ProgressView()

            Spacer()

            if elapsed >= 120 {
                Button("Continue Without Data") {
                    Task {
                        guard let token = authService.accessToken else { return }
                        await viewModel.advanceTo(step: .confirmIncome, accessToken: token)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .onAppear {
            pulseScale = 1.15
            guard let token = authService.accessToken else { return }
            viewModel.startPollingSync(accessToken: token)
        }
        .onDisappear {
            viewModel.stopPollingSync()
        }
        .task {
            // Track elapsed time for UI hints
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsed += 1
            }
        }
    }
}
