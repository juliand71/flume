import Foundation
@testable import Flume

enum IncomeFactory {

    // MARK: - Detected Stream

    static func detectedStream(
        name: String = "Direct Deposit - Acme Corp",
        estimatedAmount: Decimal = 2500,
        frequency: String = "biweekly",
        confidence: String = "high",
        occurrences: Int = 6
    ) -> DetectedIncomeStream {
        DetectedIncomeStream(
            name: name,
            estimatedAmount: estimatedAmount,
            totalAmount: estimatedAmount * Decimal(occurrences),
            periodAmount: estimatedAmount,
            frequency: frequency,
            nextExpectedDate: "2026-04-15",
            occurrences: occurrences,
            confidence: confidence,
            transactions: [
                StreamTransaction(date: "2026-03-15", amount: estimatedAmount, name: name),
                StreamTransaction(date: "2026-03-01", amount: estimatedAmount, name: name)
            ]
        )
    }

    // MARK: - Detection Response

    static func detectionResponse(
        streams: [DetectedIncomeStream]? = nil,
        monthlyExpense: Decimal = 3200,
        dateRangeDays: Int = 90,
        expandedSearch: Bool? = false
    ) -> IncomeDetectionResponse {
        let resolvedStreams = streams ?? [detectedStream()]
        return IncomeDetectionResponse(
            detectedStreams: resolvedStreams,
            monthlyExpenseEstimate: monthlyExpense,
            transactionCount: 150,
            dateRangeDays: dateRangeDays,
            expandedSearch: expandedSearch
        )
    }

    // MARK: - Income Stream (confirmed)

    static func incomeStream(
        id: UUID = UUID(),
        name: String = "Salary",
        amount: Decimal = 5000,
        frequency: String = "monthly"
    ) -> IncomeStream {
        IncomeStream(
            id: id,
            userId: UUID(),
            name: name,
            estimatedAmount: amount,
            frequency: frequency,
            nextExpectedDate: "2026-04-15",
            active: true,
            createdAt: "2026-01-01T00:00:00Z"
        )
    }

    // MARK: - Presets

    static func weekly() -> DetectedIncomeStream {
        detectedStream(name: "Weekly Gig Pay", estimatedAmount: 600, frequency: "weekly", occurrences: 12)
    }

    static func biweekly() -> DetectedIncomeStream {
        detectedStream(name: "Biweekly Paycheck", estimatedAmount: 2500, frequency: "biweekly", occurrences: 6)
    }

    static func semimonthly() -> DetectedIncomeStream {
        detectedStream(name: "Semimonthly Salary", estimatedAmount: 2250, frequency: "semimonthly", occurrences: 6)
    }

    static func monthly() -> DetectedIncomeStream {
        detectedStream(name: "Monthly Salary", estimatedAmount: 5000, frequency: "monthly", occurrences: 3)
    }

    static func multipleStreams() -> [DetectedIncomeStream] {
        [monthly(), biweekly()]
    }

    static func lowConfidence() -> DetectedIncomeStream {
        detectedStream(name: "Irregular Transfer", estimatedAmount: 200, frequency: "monthly", confidence: "low", occurrences: 2)
    }
}
