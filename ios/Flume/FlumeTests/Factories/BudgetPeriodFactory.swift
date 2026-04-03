import Foundation
@testable import Flume

enum BudgetPeriodFactory {

    static func period(
        id: UUID = UUID(),
        startDate: String = "2026-04-01",
        endDate: String = "2026-05-01",
        incomeTarget: Decimal = 5000,
        fixedTarget: Decimal = 1500,
        flexTarget: Decimal = 800,
        savingsTarget: Decimal = 2700
    ) -> BudgetPeriod {
        BudgetPeriod(
            id: id,
            userId: UUID(),
            startDate: startDate,
            endDate: endDate,
            incomeTarget: incomeTarget,
            fixedTarget: fixedTarget,
            flexTarget: flexTarget,
            savingsTarget: savingsTarget,
            incomeStreamId: nil,
            createdAt: "2026-04-01T00:00:00Z",
            actualIncome: nil,
            actualFixed: nil,
            actualFlex: nil,
            actualSavings: nil,
            surplus: nil
        )
    }

    static func onboardingStatus(
        step: String? = "welcome",
        hasPlaidItems: Bool = false,
        transactionCount: Int = 0,
        hasIncomeStreams: Bool = false,
        hasBudgetPeriod: Bool = false,
        hasSavingsGoal: Bool = false
    ) -> OnboardingStatus {
        OnboardingStatus(
            onboardingStep: step,
            hasPlaidItems: hasPlaidItems,
            transactionCount: transactionCount,
            hasIncomeStreams: hasIncomeStreams,
            hasBudgetPeriod: hasBudgetPeriod,
            hasSavingsGoal: hasSavingsGoal
        )
    }

    static func syncStatus(
        hasPlaidItems: Bool = true,
        transactionCount: Int = 50
    ) -> SyncStatus {
        SyncStatus(
            hasPlaidItems: hasPlaidItems,
            transactionCount: transactionCount
        )
    }

    static func savingsGoal(
        id: UUID = UUID(),
        name: String = "Emergency Fund",
        targetAmount: Decimal = 10000,
        currentAmount: Decimal = 0,
        isEmergencyFund: Bool = true
    ) -> SavingsGoal {
        SavingsGoal(
            id: id,
            userId: UUID(),
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            emoji: nil,
            isEmergencyFund: isEmergencyFund,
            priority: 0,
            archived: false,
            createdAt: "2026-04-01T00:00:00Z"
        )
    }
}
