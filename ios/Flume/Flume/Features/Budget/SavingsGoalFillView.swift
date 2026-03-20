import SwiftUI

struct SavingsGoalFillView: View {
    @Bindable var viewModel: SavingsGoalViewModel
    let surplus: Decimal
    @Environment(\.dismiss) private var dismiss

    @State private var amounts: [UUID: String] = [:]

    private var totalAllocated: Decimal {
        amounts.values.compactMap { Decimal(string: $0) }.reduce(0, +)
    }

    private var remaining: Decimal {
        surplus - totalAllocated
    }

    private var allocations: [(savingsGoalId: String, amount: Decimal)] {
        amounts.compactMap { (id, amountString) in
            guard let amount = Decimal(string: amountString), amount > 0 else { return nil }
            return (savingsGoalId: id.uuidString, amount: amount)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Spillover")
                            .font(.headline)
                        Spacer()
                        Text(surplus, format: .currency(code: "USD"))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text(remaining, format: .currency(code: "USD"))
                            .foregroundStyle(remaining >= 0 ? .secondary : Color.red)
                    }
                }

                Section("Allocate to Buckets") {
                    ForEach(viewModel.goals) { goal in
                        HStack {
                            if let emoji = goal.emoji {
                                Text(emoji)
                            }
                            VStack(alignment: .leading) {
                                Text(goal.name)
                                    .font(.subheadline.weight(.medium))
                                Text("\(goal.currentAmount, format: .currency(code: "USD")) / \(goal.targetAmount, format: .currency(code: "USD"))")
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

                Section {
                    Button("Confirm Fill") {
                        Task {
                            let success = await viewModel.fillGoals(allocations: allocations)
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(allocations.isEmpty || remaining < 0)
                }
            }
            .navigationTitle("Fill Buckets")
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
