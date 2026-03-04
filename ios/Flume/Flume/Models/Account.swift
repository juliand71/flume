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
    let updatedAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case plaidItemId = "plaid_item_id"
        case userId = "user_id"
        case plaidAccountId = "plaid_account_id"
        case name
        case officialName = "official_name"
        case type
        case subtype
        case mask
        case currentBalance = "current_balance"
        case availableBalance = "available_balance"
        case isoCurrencyCode = "iso_currency_code"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }
}
