import SwiftUI

struct CreateSavingsGoalView: View {
    @Bindable var viewModel: SavingsGoalViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var targetAmount = ""
    @State private var emoji = ""
    @State private var isEmergencyFund = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Target Amount", text: $targetAmount)
                        .keyboardType(.decimalPad)
                    TextField("Emoji", text: $emoji)
                        .onChange(of: emoji) { _, newValue in
                            if newValue.count > 1 {
                                emoji = String(newValue.suffix(1))
                            }
                        }
                }

                Section {
                    Toggle("Emergency Fund", isOn: $isEmergencyFund)
                }
            }
            .navigationTitle("New Bucket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard let amount = Decimal(string: targetAmount), amount > 0 else { return }
                            await viewModel.createGoal(
                                name: name,
                                targetAmount: amount,
                                emoji: emoji.isEmpty ? nil : emoji,
                                isEmergencyFund: isEmergencyFund,
                                priority: 0
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || targetAmount.isEmpty)
                }
            }
        }
    }
}
