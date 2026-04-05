#if os(iOS)
import SwiftUI

struct SyncingStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var elapsed = 0
    @State private var pulseScale = 1.0
    @State private var isLinking = false
    @State private var linkToken: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if viewModel.hasSyncedTransactions {
                readyContent
            } else {
                syncingContent
            }

            Spacer()

            if viewModel.hasSyncedTransactions {
                readyButtons
            } else if elapsed >= 120 {
                Button("Continue Without Data") {
                    Task {
                        guard let token = authService.accessToken else { return }
                        await viewModel.advanceTo(step: .choosePeriod, accessToken: token)
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
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsed += 1
            }
        }
        .sheet(item: $linkToken) { token in
            PlaidLinkFlow(linkToken: token) { result in
                linkToken = nil
                Task { await handleLinkResult(result) }
            }
        }
    }

    // MARK: - Syncing State

    private var syncingContent: some View {
        Group {
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
        }
    }

    // MARK: - Ready State

    private var readyContent: some View {
        Group {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Your Accounts Are Connected!")
                .font(.title.bold())

            if !viewModel.linkedInstitutionNames.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.linkedInstitutionNames, id: \.self) { name in
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .foregroundStyle(.secondary)
                            Text(name)
                        }
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var readyButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    guard let token = authService.accessToken else { return }
                    await viewModel.advanceTo(step: .choosePeriod, accessToken: token)
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                Task { await startLink() }
            } label: {
                if isLinking {
                    ProgressView()
                } else {
                    Text("Link Another Bank")
                }
            }
            .controlSize(.large)
            .disabled(isLinking)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Plaid Link

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
            viewModel.linkedInstitutionNames.append(institutionName)
            elapsed = 0
            viewModel.restartPollingSync(accessToken: accessToken)
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
#else
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

            ProgressView()

            Spacer()

            if elapsed >= 120 {
                Button("Continue Without Data") {
                    Task {
                        guard let token = authService.accessToken else { return }
                        await viewModel.advanceTo(step: .choosePeriod, accessToken: token)
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
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsed += 1
            }
        }
    }
}
#endif
