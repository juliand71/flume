import Foundation

struct IncomeStream: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let estimatedAmount: Decimal
    let frequency: String
    let nextExpectedDate: String?
    let active: Bool
    let createdAt: String
}
