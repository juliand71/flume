import SwiftUI

struct SavingsGoalListView: View {
    @Bindable var viewModel: SavingsGoalViewModel
    @State private var showingCreateSheet = false

    var body: some View {
        Group {
            if !viewModel.goals.isEmpty {
                List {
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
                    "No Buckets",
                    systemImage: "archivebox",
                    description: Text("Create a savings goal to start filling buckets.")
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

private struct SavingsGoalRow: View {
    let goal: SavingsGoal

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return Double(truncating: goal.currentAmount / goal.targetAmount as NSDecimalNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let emoji = goal.emoji {
                    Text(emoji)
                }
                Text(goal.name)
                    .font(.subheadline.weight(.medium))
                if goal.isEmergencyFund {
                    Image(systemName: "shield.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(goal.currentAmount, format: .currency(code: "USD"))
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
                        .frame(width: max(0, geometry.size.width * min(progress, 1.0)))
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 4)
    }
}
