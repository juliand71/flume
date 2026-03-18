import Foundation

struct PersonalFinanceCategory: Codable, Sendable {
    let primary: String
    let detailed: String
}

struct Transaction: Codable, Identifiable, Sendable {
    let id: UUID
    let accountId: UUID
    let userId: UUID
    let plaidTransactionId: String
    let name: String
    let amount: Decimal
    let isoCurrencyCode: String
    let category: [String]?
    let personalFinanceCategory: PersonalFinanceCategory?
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
        case personalFinanceCategory = "personal_finance_category"
        case date
        case pending
        case createdAt = "created_at"
    }
}
