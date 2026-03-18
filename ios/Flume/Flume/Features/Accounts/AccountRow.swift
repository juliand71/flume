import SwiftUI

struct AccountRow: View {
    let account: Account

    private var roleLabel: String? {
        switch account.accountRole {
        case "checking":    return "Basin"
        case "savings":     return "Cistern"
        case "credit_card": return "Canal"
        default:            return nil
        }
    }

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

            HStack(spacing: 8) {
                if let balance = account.currentBalance {
                    Text(balance, format: .currency(code: account.isoCurrencyCode))
                        .font(.body.monospacedDigit())
                }

                if let label = roleLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }
}
