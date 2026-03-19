import Foundation

struct SavingsGoal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let targetAmount: Decimal
    let currentAmount: Decimal
    let emoji: String?
    let isEmergencyFund: Bool
    let priority: Int
    let archived: Bool
    let createdAt: String
}
