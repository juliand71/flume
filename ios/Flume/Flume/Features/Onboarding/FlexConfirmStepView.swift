import SwiftUI

struct FlexConfirmStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var flexTarget: String = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Flexible Spending")
                .font(.title.bold())

            if viewModel.isLoading {
                Spacer()
                ProgressView("Analyzing spending...")
                Spacer()
            } else {
                spendingView
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .task {
            guard let token = authService.accessToken else { return }
            await viewModel.detectFlex(accessToken: token)
            flexTarget = "\(viewModel.detectedFlexTotal)"
        }
    }

    @ViewBuilder
    private var spendingView: some View {
        Spacer()

        if viewModel.flexTransactionCount > 0 {
            Text("We detected **\(viewModel.detectedFlexTotal as NSDecimalNumber, formatter: Self.currencyFormatter)** in flexible spending across \(viewModel.flexTransactionCount) transactions.")
                .multilineTextAlignment(.center)

            Text("This includes dining, shopping, entertainment, and other discretionary spending. You can adjust this target to what you'd like to spend.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            Text("No flexible spending detected yet. Set a target for discretionary spending like dining, shopping, and entertainment.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Flex Spending Target")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("$")
                TextField("0.00", text: $flexTarget)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .textFieldStyle(.roundedBorder)
        }

        Spacer()

        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.caption)
        }

        Button {
            Task { await confirmFlex() }
        } label: {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Confirm Flex Target")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(flexTarget.isEmpty || isSaving)
    }

    private func confirmFlex() async {
        guard let token = authService.accessToken else { return }
        guard let amount = Decimal(string: flexTarget) else { return }
        isSaving = true
        defer { isSaving = false }

        viewModel.confirmedFlexTarget = amount
        await viewModel.advanceStep(accessToken: token)
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()
}
