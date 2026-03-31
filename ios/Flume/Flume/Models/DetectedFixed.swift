import Foundation

struct DetectedFixedExpense: Codable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let totalAmount: Decimal
    let occurrences: Int
    let plaidCategory: String
    let transactions: [StreamTransaction]
}

struct FixedDetectionResponse: Codable, Sendable {
    let detectedExpenses: [DetectedFixedExpense]
    let totalFixed: Decimal
}
