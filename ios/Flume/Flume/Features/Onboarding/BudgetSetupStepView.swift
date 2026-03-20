import SwiftUI

struct BudgetSetupStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var startDate = ""
    @State private var endDate = ""
    @State private var incomeTarget = ""
    @State private var fixedTarget = ""
    @State private var flexTarget = ""
    @State private var savingsTarget = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Your First Budget")
                .font(.title.bold())

            if viewModel.isLoading {
                Spacer()
                ProgressView("Building your budget suggestion...")
                Spacer()
            } else {
                budgetForm
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .task {
            guard let token = authService.accessToken else { return }
            // Use the first confirmed stream (highest priority)
            if let primaryStream = viewModel.confirmedStreams.first {
                await viewModel.fetchBudgetSuggestion(
                    incomeStreamId: primaryStream.id.uuidString,
                    accessToken: token
                )
            }
            if let suggestion = viewModel.budgetSuggestion {
                startDate = suggestion.startDate
                endDate = suggestion.endDate
                incomeTarget = "\(suggestion.incomeTarget)"
                fixedTarget = "\(suggestion.fixedTarget)"
                flexTarget = "\(suggestion.flexTarget)"
                savingsTarget = "\(suggestion.savingsTarget)"
            }
        }
    }

    @ViewBuilder
    private var budgetForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("We suggest a 50/30/20 split based on your income. You can adjust these targets anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Group {
                    labeledField("Period Start", text: $startDate)
                    labeledField("Period End", text: $endDate)
                }

                Divider()

                Group {
                    targetField("Income (Source)", text: $incomeTarget, icon: "arrow.down.circle")
                    targetField("Fixed Expenses", text: $fixedTarget, icon: "lock.circle")
                    targetField("Flex Spending", text: $flexTarget, icon: "creditcard.circle")
                    targetField("Savings", text: $savingsTarget, icon: "banknote.circle")
                }
            }
        }

        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.caption)
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
        .disabled(isSaving || startDate.isEmpty || endDate.isEmpty)
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func targetField(_ label: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("$")
                TextField("0.00", text: text)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    private func createBudget() async {
        guard let token = authService.accessToken else { return }
        isSaving = true
        defer { isSaving = false }

        let income = Decimal(string: incomeTarget) ?? 0
        let fixed = Decimal(string: fixedTarget) ?? 0
        let flex = Decimal(string: flexTarget) ?? 0
        let savings = Decimal(string: savingsTarget) ?? 0

        let success = await viewModel.createBudgetPeriod(
            startDate: startDate,
            endDate: endDate,
            incomeTarget: income,
            fixedTarget: fixed,
            flexTarget: flex,
            savingsTarget: savings,
            incomeStreamId: viewModel.confirmedStreams.first?.id.uuidString,
            accessToken: token
        )
        if success {
            await viewModel.advanceStep(accessToken: token)
        }
    }
}
