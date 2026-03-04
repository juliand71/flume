import Foundation

struct Transaction: Codable, Identifiable, Sendable {
    let id: UUID
    let accountId: UUID
    let userId: UUID
    let plaidTransactionId: String
    let name: String
    let amount: Decimal
    let isoCurrencyCode: String
    let category: [String]?
    let date: String
    let pending: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case userId = "user_id"
        case plaidTransactionId = "plaid_transaction_id"
        case name
        case amount
        case isoCurrencyCode = "iso_currency_code"
        case category
        case date
        case pending
        case createdAt = "created_at"
    }
}
