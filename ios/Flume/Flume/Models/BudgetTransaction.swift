import Foundation

struct BudgetTransaction: Codable, Identifiable, Sendable {
    let id: UUID
    let accountId: UUID
    let name: String
    let amount: Decimal
    let isoCurrencyCode: String
    let date: String
    let pending: Bool
    let budgetCategory: String
    let categoryOverride: String?
}
