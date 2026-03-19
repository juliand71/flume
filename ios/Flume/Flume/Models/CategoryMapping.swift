import Foundation

struct CategoryMapping: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID?
    let plaidPrimaryCategory: String
    let plaidDetailedCategory: String?
    let budgetCategory: String
    let createdAt: String
}
