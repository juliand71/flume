import SwiftUI
import Supabase

struct SavingsGoalDetailView: View {
    @Bindable var viewModel: SavingsGoalViewModel
    let goal: SavingsGoal
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var emoji: String = ""
    @State private var isEmergencyFund: Bool = false
    @State private var showingDeleteConfirmation = false
    @State private var transactions: [BudgetTransaction] = []
    @State private var isLoadingTransactions = false

    private var effectiveAmount: Decimal {
        goal.balance ?? goal.currentAmount
    }

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return Double(truncating: effectiveAmount / goal.targetAmount as NSDecimalNumber)
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    HStack {
                        Text(effectiveAmount, format: .currency(code: "USD"))
                            .font(.title.weight(.semibold))
                        Text("of")
                            .foregroundStyle(.secondary)
                        Text(goal.targetAmount, format: .currency(code: "USD"))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.15))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green)
                                .frame(width: max(0, geometry.size.width * min(max(progress, 0), 1.0)))
                        }
                    }
                    .frame(height: 16)

                    Text("\(Int(max(progress, 0) * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let spent = goal.spent, spent > 0 {
                        HStack {
                            Text("Spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(spent, format: .currency(code: "USD"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Spending") {
                if isLoadingTransactions {
                    ProgressView()
                } else if transactions.isEmpty {
                    Text("No transactions linked to this goal")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(transactions) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.name)
                                    .lineLimit(1)
                                Text(transaction.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(abs(transaction.amount), format: .currency(code: transaction.isoCurrencyCode))
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Edit") {
                TextField("Name", text: $name)
                TextField("Target Amount", text: $targetAmount)
                    .keyboardType(.decimalPad)
                TextField("Emoji", text: $emoji)
                    .onChange(of: emoji) { _, newValue in
                        if newValue.count > 1 {
                            emoji = String(newValue.suffix(1))
                        }
                    }
                Toggle("Emergency Fund", isOn: $isEmergencyFund)
            }

            Section {
                Button("Save Changes") {
                    Task {
                        let amount = Decimal(string: targetAmount)
                        await viewModel.updateGoal(
                            id: goal.id.uuidString,
                            name: name.isEmpty ? nil : name,
                            targetAmount: amount,
                            emoji: emoji.isEmpty ? nil : emoji,
                            isEmergencyFund: isEmergencyFund,
                            priority: nil
                        )
                        dismiss()
                    }
                }
            }

            Section {
                Button("Delete Goal", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(goal.emoji.map { "\($0) \(goal.name)" } ?? goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this savings goal?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteGoal(id: goal.id.uuidString)
                    dismiss()
                }
            }
        }
        .onAppear {
            name = goal.name
            targetAmount = "\(goal.targetAmount)"
            emoji = goal.emoji ?? ""
            isEmergencyFund = goal.isEmergencyFund
        }
        .task {
            isLoadingTransactions = true
            do {
                let accessToken = try await SupabaseService.shared.auth.session.accessToken
                transactions = try await BudgetAPIService.shared.fetchSavingsGoalTransactions(
                    goalId: goal.id.uuidString,
                    accessToken: accessToken
                )
            } catch {}
            isLoadingTransactions = false
        }
    }
}
