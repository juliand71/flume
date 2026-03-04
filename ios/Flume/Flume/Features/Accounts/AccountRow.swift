import SwiftUI

struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body)
                if let officialName = account.officialName {
                    Text(officialName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let balance = account.currentBalance {
                Text(balance, format: .currency(code: account.isoCurrencyCode))
                    .font(.body.monospacedDigit())
            }
        }
        .padding(.vertical, 2)
    }
}
