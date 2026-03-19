import SwiftUI

struct SavingsGoalDetailView: View {
    @Bindable var viewModel: SavingsGoalViewModel
    let goal: SavingsGoal
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var emoji: String = ""
    @State private var isEmergencyFund: Bool = false
    @State private var showingDeleteConfirmation = false

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return Double(truncating: goal.currentAmount / goal.targetAmount as NSDecimalNumber)
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    HStack {
                        Text(goal.currentAmount, format: .currency(code: "USD"))
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
                                .frame(width: max(0, geometry.size.width * min(progress, 1.0)))
                        }
                    }
                    .frame(height: 16)

                    Text("\(Int(progress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
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
                Button("Delete Bucket", role: .destructive) {
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
    }
}
