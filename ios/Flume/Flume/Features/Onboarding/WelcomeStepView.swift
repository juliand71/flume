import SwiftUI

struct WelcomeStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Flume")
                .font(.largeTitle.bold())

            Text("Take control of your finances.\nConnect your bank, track your spending, and build your savings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    guard let token = authService.accessToken else { return }
                    await viewModel.advanceStep(accessToken: token)
                }
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: 400)
    }
}
