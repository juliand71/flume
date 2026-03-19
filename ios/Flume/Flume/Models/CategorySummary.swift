import Foundation

struct CategorySummaryResponse: Codable, Sendable {
    let periodId: UUID
    let startDate: String
    let endDate: String
    let categories: [CategoryEntry]
    let surplus: Decimal
}

struct CategoryEntry: Codable, Identifiable, Sendable {
    var id: String { category }
    let category: String
    let target: Decimal
    let actual: Decimal
}
