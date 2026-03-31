import SwiftUI

struct FixedConfirmStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var adjustedAmounts: [String: String] = [:]
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Fixed Expenses")
                .font(.title.bold())

            Text("These are recurring expenses we detected like rent, utilities, and loan payments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.isLoading {
                Spacer()
                ProgressView("Detecting fixed expenses...")
                Spacer()
            } else if viewModel.detectedFixedExpenses.isEmpty {
                noExpensesView
            } else {
                expenseListView
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .task {
            guard let token = authService.accessToken else { return }
            await viewModel.detectFixed(accessToken: token)
            for expense in viewModel.detectedFixedExpenses {
                adjustedAmounts[expense.name] = "\(expense.totalAmount)"
            }
        }
    }

    @ViewBuilder
    private var noExpensesView: some View {
        Spacer()

        Text("No fixed expenses detected yet. You can set your expected fixed expense amount manually.")
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 4) {
            Text("Expected Fixed Expenses")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("$")
                TextField("0.00", text: Binding(
                    get: { "\(viewModel.confirmedFixedTotal)" },
                    set: { viewModel.confirmedFixedTotal = Decimal(string: $0) ?? 0 }
                ))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            }
            .textFieldStyle(.roundedBorder)
        }

        Spacer()

        confirmButton
    }

    @ViewBuilder
    private var expenseListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.detectedFixedExpenses) { expense in
                    expenseCard(expense: expense)
                }
            }
        }

        HStack {
            Text("Total Fixed Expenses")
                .font(.headline)
            Spacer()
            Text(computedTotal, format: .currency(code: "USD"))
                .font(.title3.weight(.semibold))
        }
        .padding(.vertical, 4)

        confirmButton
    }

    @ViewBuilder
    private func expenseCard(expense: DetectedFixedExpense) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(expense.name)
                .font(.headline)

            HStack {
                Text("$")
                TextField("0.00", text: Binding(
                    get: { adjustedAmounts[expense.name] ?? "\(expense.totalAmount)" },
                    set: { adjustedAmounts[expense.name] = $0 }
                ))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            }
            .textFieldStyle(.roundedBorder)

            DisclosureGroup("Transactions (\(expense.occurrences))") {
                VStack(spacing: 4) {
                    ForEach(expense.transactions) { txn in
                        HStack {
                            Text(txn.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(txn.amount, format: .currency(code: "USD"))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding(.top, 4)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var confirmButton: some View {
        Button {
            Task { await confirmFixed() }
        } label: {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Confirm Fixed Expenses")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isSaving)
    }

    private var computedTotal: Decimal {
        var total: Decimal = 0
        for expense in viewModel.detectedFixedExpenses {
            if let str = adjustedAmounts[expense.name], let val = Decimal(string: str) {
                total += val
            } else {
                total += expense.totalAmount
            }
        }
        return total
    }

    private func confirmFixed() async {
        guard let token = authService.accessToken else { return }
        isSaving = true
        defer { isSaving = false }

        viewModel.confirmedFixedTotal = computedTotal
        await viewModel.advanceStep(accessToken: token)
    }
}
