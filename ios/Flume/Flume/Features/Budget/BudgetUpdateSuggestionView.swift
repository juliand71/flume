import SwiftUI

struct BudgetUpdateSuggestionView: View {
    @Bindable var viewModel: BudgetPeriodViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("New account data suggests updated budget targets.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let period = viewModel.currentPeriod, let suggestions = viewModel.suggestions {
                    Section("Suggested Changes") {
                        if let income = suggestions.incomeTarget {
                            SuggestionRow(title: "Income", current: period.incomeTarget, suggested: income)
                        }
                        if let fixed = suggestions.fixedTarget {
                            SuggestionRow(title: "Fixed", current: period.fixedTarget, suggested: fixed)
                        }
                        if let flex = suggestions.flexTarget {
                            SuggestionRow(title: "Flex", current: period.flexTarget, suggested: flex)
                        }
                        if let savings = suggestions.savingsTarget {
                            SuggestionRow(title: "Savings", current: period.savingsTarget, suggested: savings)
                        }
                    }
                }

                Section {
                    Button("Update Budget") {
                        Task {
                            await viewModel.applySuggestions()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("Budget Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") {
                        viewModel.dismissSuggestions()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SuggestionRow: View {
    let title: String
    let current: Decimal
    let suggested: Decimal

    private var isIncrease: Bool { suggested > current }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
            HStack {
                Text(current, format: .currency(code: "USD"))
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(suggested, format: .currency(code: "USD"))
                    .foregroundStyle(isIncrease ? .green : .orange)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
