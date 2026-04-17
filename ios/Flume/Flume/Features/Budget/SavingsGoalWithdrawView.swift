import SwiftUI

struct SavingsGoalWithdrawView: View {
    @Bindable var viewModel: SavingsGoalViewModel
    let deficit: Decimal
    let budgetPeriodId: String
    @Environment(\.dismiss) private var dismiss

    @State private var amounts: [UUID: String] = [:]

    private var totalWithdrawal: Decimal {
        amounts.values.compactMap { Decimal(string: $0) }.reduce(0, +)
    }

    private var remaining: Decimal {
        deficit - totalWithdrawal
    }

    private var withdrawals: [(savingsGoalId: String, amount: Decimal)] {
        amounts.compactMap { (id, amountString) in
            guard let amount = Decimal(string: amountString), amount > 0 else { return nil }
            return (savingsGoalId: id.uuidString, amount: amount)
        }
    }

    private var eligibleGoals: [SavingsGoal] {
        viewModel.goals.filter { !$0.archived && ($0.balance ?? $0.currentAmount) > 0 }
    }

    private var hasOverage: Bool {
        for (id, amountString) in amounts {
            guard let amount = Decimal(string: amountString), amount > 0,
                  let goal = eligibleGoals.first(where: { $0.id == id }) else { continue }
            if amount > (goal.balance ?? goal.currentAmount) { return true }
        }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Deficit")
                            .font(.headline)
                        Spacer()
                        Text(deficit, format: .currency(code: "USD"))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text(remaining, format: .currency(code: "USD"))
                            .foregroundStyle(remaining >= 0 ? .secondary : Color.red)
                    }
                }

                Section("Withdraw from Goals") {
                    if eligibleGoals.isEmpty {
                        Text("No goals with available balance")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(eligibleGoals) { goal in
                            HStack {
                                if let emoji = goal.emoji {
                                    Text(emoji)
                                }
                                VStack(alignment: .leading) {
                                    Text(goal.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(goal.balance ?? goal.currentAmount, format: .currency(code: "USD")) available")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                TextField("$0", text: binding(for: goal.id))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button("Confirm Withdrawal") {
                        Task {
                            let success = await viewModel.withdrawFromGoals(
                                withdrawals: withdrawals,
                                budgetPeriodId: budgetPeriodId
                            )
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(withdrawals.isEmpty || remaining < 0 || hasOverage)
                }
            }
            .navigationTitle("Withdraw from Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if viewModel.goals.isEmpty {
                    await viewModel.fetchGoals()
                }
            }
        }
    }

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { amounts[id, default: ""] },
            set: { amounts[id] = $0 }
        )
    }
}
