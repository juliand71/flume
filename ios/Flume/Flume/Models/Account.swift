import Foundation

struct Account: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let plaidItemId: UUID
    let userId: UUID
    let plaidAccountId: String
    let name: String
    let officialName: String?
    let type: String
    let subtype: String
    let mask: String?
    let currentBalance: Decimal?
    let availableBalance: Decimal?
    let isoCurrencyCode: String
    let accountRole: String?
    let updatedAt: String?
    let createdAt: String
}
