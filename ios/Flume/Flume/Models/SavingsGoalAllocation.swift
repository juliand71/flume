import Foundation

struct SavingsGoalAllocation: Codable, Identifiable, Sendable {
    let id: UUID
    let savingsGoalId: UUID
    let goalName: String
    let goalEmoji: String?
    let amount: Decimal
    let createdAt: String
}
