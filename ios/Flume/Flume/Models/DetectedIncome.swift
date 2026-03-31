import Foundation

struct StreamTransaction: Codable, Sendable, Identifiable {
    var id: String { "\(date)-\(amount)-\(name)" }
    let date: String
    let amount: Decimal
    let name: String
}

struct DetectedIncomeStream: Codable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let estimatedAmount: Decimal
    let totalAmount: Decimal
    let frequency: String
    let nextExpectedDate: String?
    let occurrences: Int
    let confidence: String
    let transactions: [StreamTransaction]
}

struct IncomeDetectionResponse: Codable, Sendable {
    let detectedStreams: [DetectedIncomeStream]
    let monthlyExpenseEstimate: Decimal
    let transactionCount: Int
    let dateRangeDays: Int
    let expandedSearch: Bool?
}

struct BudgetSuggestion: Codable, Sendable {
    let startDate: String
    let endDate: String
    let incomeTarget: Decimal
    let fixedTarget: Decimal
    let flexTarget: Decimal
    let savingsTarget: Decimal
}
