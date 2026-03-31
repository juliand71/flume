import SwiftUI

struct ReviewSavingsStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Your Budget Summary")
                .font(.title.bold())

            Text("Here's how your budget breaks down for this period.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            summaryCard

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if viewModel.projectedSavings < 0 {
                Text("Your expenses exceed your income. Consider going back to adjust your targets.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await createBudget() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Budget")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSaving)
        }
        .padding()
        .frame(maxWidth: 400)
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(spacing: 16) {
            summaryRow(label: "Income", amount: viewModel.confirmedIncomeTotal, color: .blue)

            Divider()

            summaryRow(label: "Fixed Expenses", amount: viewModel.confirmedFixedTotal, color: .orange, negative: true)
            summaryRow(label: "Flex Spending", amount: viewModel.confirmedFlexTarget, color: .purple, negative: true)

            Divider()

            HStack {
                Text("Projected Savings")
                    .font(.headline)
                Spacer()
                Text(viewModel.projectedSavings, format: .currency(code: "USD"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(viewModel.projectedSavings >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func summaryRow(label: String, amount: Decimal, color: Color, negative: Bool = false) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(negative ? "-" : "")\(amount, format: .currency(code: "USD"))")
                .font(.subheadline.monospacedDigit())
        }
    }

    private func createBudget() async {
        guard let token = authService.accessToken else { return }
        isSaving = true
        defer { isSaving = false }

        let success = await viewModel.createBudgetFromConfirmedValues(accessToken: token)
        if success {
            await viewModel.advanceStep(accessToken: token)
        }
    }
}
