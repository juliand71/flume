import SwiftUI

struct SavingsGoalStepView: View {
    let viewModel: OnboardingViewModel
    let onComplete: () -> Void
    @Environment(AuthService.self) private var authService

    @State private var targetAmount = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lifepreserver")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Emergency Fund")
                .font(.title.bold())

            Text("Financial experts recommend saving 3–6 months of expenses. We'll help you get there.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Target Amount")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("$")
                    TextField("0.00", text: $targetAmount)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                .textFieldStyle(.roundedBorder)

                if viewModel.monthlyExpenseEstimate > 0 {
                    let threeMonths = viewModel.monthlyExpenseEstimate * 3
                    let sixMonths = viewModel.monthlyExpenseEstimate * 6
                    Text("Based on your spending: $\(threeMonths) – $\(sixMonths)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task { await createFund() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Emergency Fund")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(targetAmount.isEmpty || isSaving)

            Button("Skip for Now") {
                Task { await skipAndComplete() }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: 400)
        .onAppear {
            // Pre-fill with 3 months of expenses
            if viewModel.monthlyExpenseEstimate > 0 {
                let suggested = viewModel.monthlyExpenseEstimate * 3
                targetAmount = "\(suggested)"
            }
        }
    }

    private func createFund() async {
        guard let token = authService.accessToken else { return }
        guard let amount = Decimal(string: targetAmount), amount > 0 else { return }
        isSaving = true
        defer { isSaving = false }

        let success = await viewModel.createEmergencyFund(targetAmount: amount, accessToken: token)
        if success {
            await viewModel.advanceTo(step: .complete, accessToken: token)
            onComplete()
        }
    }

    private func skipAndComplete() async {
        guard let token = authService.accessToken else { return }
        await viewModel.advanceTo(step: .complete, accessToken: token)
        onComplete()
    }
}
