import SwiftUI
import Supabase

struct CategoryDetailView: View {
    @State var viewModel: CategoryDetailViewModel
    let categoryTitle: String
    let tint: Color

    @State private var selectedTransaction: BudgetTransaction?
    @State private var pendingSavingsTransaction: BudgetTransaction?
    @State private var savingsGoals: [SavingsGoal] = []

    private var groupedTransactions: [(String, [BudgetTransaction])] {
        let grouped = Dictionary(grouping: viewModel.transactions) { $0.date }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                ProgressView()
            } else if viewModel.transactions.isEmpty {
                ContentUnavailableView(
                    "No Flows",
                    systemImage: "drop",
                    description: Text("No transactions in this category for the current period.")
                )
            } else {
                List {
                    ForEach(groupedTransactions, id: \.0) { date, transactions in
                        Section(header: Text(date)) {
                            ForEach(transactions) { transaction in
                                CategoryTransactionRow(transaction: transaction)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTransaction = transaction
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(categoryTitle) Flows")
        .refreshable {
            await viewModel.fetchTransactions()
        }
        .task {
            await viewModel.fetchTransactions()
        }
        .confirmationDialog(
            "Change Category",
            isPresented: Binding(
                get: { selectedTransaction != nil },
                set: { if !$0 { selectedTransaction = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(["income", "fixed", "flex", "savings", "transfer", "ignore"], id: \.self) { category in
                Button(category.capitalized) {
                    if let tx = selectedTransaction {
                        if category == "savings" {
                            pendingSavingsTransaction = tx
                        } else {
                            Task {
                                await viewModel.overrideCategory(
                                    transactionId: tx.id.uuidString,
                                    newCategory: category
                                )
                            }
                        }
                    }
                    selectedTransaction = nil
                }
            }
            Button("Cancel", role: .cancel) {
                selectedTransaction = nil
            }
        } message: {
            if let tx = selectedTransaction {
                Text("Recategorize \"\(tx.name)\"")
            }
        }
        .sheet(isPresented: Binding(
            get: { pendingSavingsTransaction != nil },
            set: { if !$0 { pendingSavingsTransaction = nil } }
        )) {
            NavigationStack {
                List {
                    if savingsGoals.isEmpty {
                        Text("No savings goals available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savingsGoals.filter { !$0.archived }) { goal in
                            Button {
                                if let tx = pendingSavingsTransaction {
                                    Task {
                                        await viewModel.overrideCategory(
                                            transactionId: tx.id.uuidString,
                                            newCategory: "savings",
                                            savingsGoalId: goal.id.uuidString
                                        )
                                    }
                                }
                                pendingSavingsTransaction = nil
                            } label: {
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
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("Link to Goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { pendingSavingsTransaction = nil }
                    }
                }
                .task {
                    do {
                        let accessToken = try await SupabaseService.shared.auth.session.accessToken
                        savingsGoals = try await BudgetAPIService.shared.fetchSavingsGoals(accessToken: accessToken)
                    } catch {}
                }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct CategoryTransactionRow: View {
    let transaction: BudgetTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name)
                    .lineLimit(1)
                if transaction.categoryOverride != nil {
                    Text("Recategorized")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if transaction.savingsGoalId != nil {
                    Text("Linked to goal")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            let isDeposit = transaction.amount < 0
            Text(abs(transaction.amount), format: .currency(code: transaction.isoCurrencyCode))
                .fontWeight(.medium)
                .foregroundStyle(isDeposit ? .green : .primary)
        }
        .padding(.vertical, 2)
    }
}
