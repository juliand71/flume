import Foundation

struct BudgetPeriod: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let startDate: String
    let endDate: String
    let incomeTarget: Decimal
    let fixedTarget: Decimal
    let flexTarget: Decimal
    let savingsTarget: Decimal
    let incomeStreamId: UUID?
    let createdAt: String
    // Actuals — present when fetching current period
    let actualIncome: Decimal?
    let actualFixed: Decimal?
    let actualFlex: Decimal?
    let actualSavings: Decimal?
    let surplus: Decimal?
}
