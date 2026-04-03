import Foundation
@testable import Flume

enum FixedExpenseFactory {

    static func expense(
        name: String = "Netflix",
        totalAmount: Decimal = 15.99,
        occurrences: Int = 3,
        category: String = "ENTERTAINMENT"
    ) -> DetectedFixedExpense {
        DetectedFixedExpense(
            name: name,
            totalAmount: totalAmount,
            occurrences: occurrences,
            plaidCategory: category,
            transactions: [
                StreamTransaction(date: "2026-03-01", amount: totalAmount / Decimal(occurrences), name: name),
                StreamTransaction(date: "2026-02-01", amount: totalAmount / Decimal(occurrences), name: name)
            ]
        )
    }

    static func detectionResponse(
        expenses: [DetectedFixedExpense]? = nil,
        totalFixed: Decimal = 1200
    ) -> FixedDetectionResponse {
        let resolvedExpenses = expenses ?? typicalExpenses()
        return FixedDetectionResponse(
            detectedExpenses: resolvedExpenses,
            totalFixed: totalFixed
        )
    }

    static func typicalExpenses() -> [DetectedFixedExpense] {
        [
            expense(name: "Rent Payment", totalAmount: 4500, occurrences: 3, category: "RENT"),
            expense(name: "Netflix", totalAmount: 47.97, occurrences: 3, category: "ENTERTAINMENT"),
            expense(name: "Car Insurance", totalAmount: 450, occurrences: 3, category: "INSURANCE"),
            expense(name: "Internet", totalAmount: 239.97, occurrences: 3, category: "UTILITIES")
        ]
    }
}
