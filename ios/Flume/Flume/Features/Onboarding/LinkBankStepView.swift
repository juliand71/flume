#if os(iOS)
import SwiftUI

struct LinkBankStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var isLinking = false
    @State private var linkToken: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "building.columns")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Connect Your Bank")
                .font(.title.bold())

            Text("Link your bank account so Flume can analyze your spending and help you build a budget.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task { await startLink() }
            } label: {
                if isLinking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Link Bank Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLinking)
        }
        .padding()
        .frame(maxWidth: 400)
        .sheet(item: $linkToken) { token in
            PlaidLinkFlow(linkToken: token) { result in
                linkToken = nil
                Task { await handleLinkResult(result) }
            }
        }
    }

    private func startLink() async {
        guard let accessToken = authService.accessToken else { return }
        isLinking = true
        defer { isLinking = false }
        do {
            let token = try await APIService.shared.createLinkToken(accessToken: accessToken)
            linkToken = token
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleLinkResult(_ result: PlaidLinkResult) async {
        guard let accessToken = authService.accessToken else { return }
        switch result {
        case .success(let publicToken, let institutionName, let institutionId):
            // Advance to syncing step immediately, fire exchange in background
            await viewModel.advanceTo(step: .syncing, accessToken: accessToken)
            Task {
                try? await APIService.shared.exchangePublicToken(
                    publicToken,
                    institutionName: institutionName,
                    institutionId: institutionId,
                    accessToken: accessToken
                )
            }
        case .cancelled:
            break
        case .failure(let message):
            errorMessage = message
        }
    }
}
#endif
