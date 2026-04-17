import SwiftUI

struct SavingsGoalListView: View {
    @Bindable var viewModel: SavingsGoalViewModel
    @State private var showingCreateSheet = false

    var body: some View {
        Group {
            if !viewModel.goals.isEmpty {
                List {
                    if viewModel.unallocatedSavings > 0 {
                        Section {
                            UnallocatedSavingsRow(amount: viewModel.unallocatedSavings)
                        }
                    }
                    ForEach(viewModel.goals) { goal in
                        NavigationLink {
                            SavingsGoalDetailView(viewModel: viewModel, goal: goal)
                        } label: {
                            SavingsGoalRow(goal: goal)
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView(
                    "No Goals",
                    systemImage: "archivebox",
                    description: Text("Create a savings goal to start tracking progress.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateSavingsGoalView(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.fetchGoals()
        }
        .task {
            await viewModel.fetchGoals()
        }
    }
}

private struct UnallocatedSavingsRow: View {
    let amount: Decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unallocated Savings")
                    .font(.subheadline.weight(.medium))
                Text("Not yet assigned to a goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }
}

private struct SavingsGoalRow: View {
    let goal: SavingsGoal

    private var effectiveAmount: Decimal {
        goal.balance ?? goal.currentAmount
    }

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return Double(truncating: effectiveAmount / goal.targetAmount as NSDecimalNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let emoji = goal.emoji {
                    Text(emoji)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline.weight(.medium))
                    if let spent = goal.spent, spent > 0 {
                        Text("\(spent, format: .currency(code: "USD")) spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if goal.isEmergencyFund {
                    Image(systemName: "shield.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(effectiveAmount, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("/")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(goal.targetAmount, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.15))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green)
                        .frame(width: max(0, geometry.size.width * min(max(progress, 0), 1.0)))
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 4)
    }
}
