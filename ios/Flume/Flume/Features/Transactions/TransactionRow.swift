import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.name)
                        .font(.body)
                    if transaction.pending {
                        Text("Pending")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }
                Text(transaction.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Plaid: negative = deposit, positive = expense.
            // Show deposits in green with a "+" prefix.
            let isDeposit = transaction.amount < 0
            Text(abs(transaction.amount), format: .currency(code: transaction.isoCurrencyCode))
                .font(.body.monospacedDigit())
                .foregroundStyle(isDeposit ? .green : .primary)
        }
        .padding(.vertical, 2)
    }
}
