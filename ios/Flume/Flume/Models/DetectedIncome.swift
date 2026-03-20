import Foundation

struct DetectedIncomeStream: Codable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let estimatedAmount: Decimal
    let frequency: String
    let nextExpectedDate: String?
    let occurrences: Int
    let confidence: String
}

struct IncomeDetectionResponse: Codable, Sendable {
    let detectedStreams: [DetectedIncomeStream]
    let monthlyExpenseEstimate: Decimal
    let transactionCount: Int
    let dateRangeDays: Int
}

struct BudgetSuggestion: Codable, Sendable {
    let startDate: String
    let endDate: String
    let incomeTarget: Decimal
    let fixedTarget: Decimal
    let flexTarget: Decimal
    let savingsTarget: Decimal
}
