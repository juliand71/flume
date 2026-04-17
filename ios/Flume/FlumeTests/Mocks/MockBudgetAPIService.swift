import Foundation
@testable import Flume

final class MockBudgetAPIService: BudgetAPIServiceProtocol, @unchecked Sendable {

    // MARK: - fetchOnboardingStatus

    var fetchOnboardingStatusResult: Result<OnboardingStatus, Error> = .success(
        OnboardingStatus(onboardingStep: "welcome", hasPlaidItems: false, transactionCount: 0, hasIncomeStreams: false, hasBudgetPeriod: false, hasSavingsGoal: false)
    )
    var fetchOnboardingStatusCalls: [String] = []

    func fetchOnboardingStatus(accessToken: String) async throws -> OnboardingStatus {
        fetchOnboardingStatusCalls.append(accessToken)
        return try fetchOnboardingStatusResult.get()
    }

    // MARK: - updateOnboardingStep

    var updateOnboardingStepResult: Result<OnboardingStatus, Error> = .success(
        OnboardingStatus(onboardingStep: "link_bank", hasPlaidItems: false, transactionCount: 0, hasIncomeStreams: false, hasBudgetPeriod: false, hasSavingsGoal: false)
    )
    var updateOnboardingStepCalls: [(step: String, accessToken: String)] = []

    func updateOnboardingStep(step: String, accessToken: String) async throws -> OnboardingStatus {
        updateOnboardingStepCalls.append((step: step, accessToken: accessToken))
        return try updateOnboardingStepResult.get()
    }

    // MARK: - fetchSyncStatus

    var fetchSyncStatusResult: Result<SyncStatus, Error> = .success(
        SyncStatus(hasPlaidItems: true, transactionCount: 50)
    )
    var fetchSyncStatusCalls: [String] = []

    func fetchSyncStatus(accessToken: String) async throws -> SyncStatus {
        fetchSyncStatusCalls.append(accessToken)
        return try fetchSyncStatusResult.get()
    }

    // MARK: - detectIncome

    var detectIncomeResult: Result<IncomeDetectionResponse, Error> = .success(
        IncomeDetectionResponse(detectedStreams: [], monthlyExpenseEstimate: 2000, transactionCount: 50, dateRangeDays: 90, expandedSearch: false)
    )
    var detectIncomeCalls: [(startDate: String?, endDate: String?, accessToken: String)] = []

    func detectIncome(startDate: String?, endDate: String?, accessToken: String) async throws -> IncomeDetectionResponse {
        detectIncomeCalls.append((startDate: startDate, endDate: endDate, accessToken: accessToken))
        return try detectIncomeResult.get()
    }

    // MARK: - detectFixed

    var detectFixedResult: Result<FixedDetectionResponse, Error> = .success(
        FixedDetectionResponse(detectedExpenses: [], totalFixed: 500)
    )
    var detectFixedCalls: [(startDate: String, endDate: String, accessToken: String)] = []

    func detectFixed(startDate: String, endDate: String, accessToken: String) async throws -> FixedDetectionResponse {
        detectFixedCalls.append((startDate: startDate, endDate: endDate, accessToken: accessToken))
        return try detectFixedResult.get()
    }

    // MARK: - detectFlex

    var detectFlexResult: Result<FlexDetectionResponse, Error> = .success(
        FlexDetectionResponse(totalFlex: 800, transactionCount: 120)
    )
    var detectFlexCalls: [(startDate: String, endDate: String, accessToken: String)] = []

    func detectFlex(startDate: String, endDate: String, accessToken: String) async throws -> FlexDetectionResponse {
        detectFlexCalls.append((startDate: startDate, endDate: endDate, accessToken: accessToken))
        return try detectFlexResult.get()
    }

    // MARK: - createIncomeStream

    var createIncomeStreamResult: Result<IncomeStream, Error> = .success(
        IncomeStream(id: UUID(), userId: UUID(), name: "Salary", estimatedAmount: 5000, frequency: "monthly", nextExpectedDate: nil, active: true, createdAt: "2026-01-01T00:00:00Z")
    )
    var createIncomeStreamCalls: [(name: String, estimatedAmount: Decimal, frequency: String, nextExpectedDate: String?, accessToken: String)] = []

    func createIncomeStream(name: String, estimatedAmount: Decimal, frequency: String, nextExpectedDate: String?, accessToken: String) async throws -> IncomeStream {
        createIncomeStreamCalls.append((name: name, estimatedAmount: estimatedAmount, frequency: frequency, nextExpectedDate: nextExpectedDate, accessToken: accessToken))
        return try createIncomeStreamResult.get()
    }

    // MARK: - createPeriod

    var createPeriodResult: Result<BudgetPeriod, Error> = .success(
        BudgetPeriod(id: UUID(), userId: UUID(), startDate: "2026-04-01", endDate: "2026-05-01", incomeTarget: 5000, fixedTarget: 1500, flexTarget: 800, savingsTarget: 2700, incomeStreamId: nil, createdAt: "2026-04-01T00:00:00Z", actualIncome: nil, actualFixed: nil, actualFlex: nil, actualSavings: nil, totalFilled: nil, surplus: nil, carryoverAmount: nil)
    )
    var createPeriodCalls: [(startDate: String, endDate: String, incomeTarget: Decimal, fixedTarget: Decimal, flexTarget: Decimal, savingsTarget: Decimal, incomeStreamId: String?, accessToken: String)] = []

    func createPeriod(startDate: String, endDate: String, incomeTarget: Decimal, fixedTarget: Decimal, flexTarget: Decimal, savingsTarget: Decimal, incomeStreamId: String?, accessToken: String) async throws -> BudgetPeriod {
        createPeriodCalls.append((startDate: startDate, endDate: endDate, incomeTarget: incomeTarget, fixedTarget: fixedTarget, flexTarget: flexTarget, savingsTarget: savingsTarget, incomeStreamId: incomeStreamId, accessToken: accessToken))
        return try createPeriodResult.get()
    }

    // MARK: - createSavingsGoal

    var createSavingsGoalResult: Result<SavingsGoal, Error> = .success(
        SavingsGoal(id: UUID(), userId: UUID(), name: "Emergency Fund", targetAmount: 10000, currentAmount: 0, spent: nil, balance: nil, emoji: nil, isEmergencyFund: true, priority: 0, archived: false, createdAt: "2026-04-01T00:00:00Z")
    )
    var createSavingsGoalCalls: [(name: String, targetAmount: Decimal, emoji: String?, isEmergencyFund: Bool, priority: Int, accessToken: String)] = []

    func createSavingsGoal(name: String, targetAmount: Decimal, emoji: String?, isEmergencyFund: Bool, priority: Int, accessToken: String) async throws -> SavingsGoal {
        createSavingsGoalCalls.append((name: name, targetAmount: targetAmount, emoji: emoji, isEmergencyFund: isEmergencyFund, priority: priority, accessToken: accessToken))
        return try createSavingsGoalResult.get()
    }

    // MARK: - fetchAccounts

    var fetchAccountsResult: Result<[Account], Error> = .success([])

    func fetchAccounts(accessToken: String) async throws -> [Account] {
        return try fetchAccountsResult.get()
    }

    // MARK: - fillSavingsGoals

    var fillSavingsGoalsResult: Result<[SavingsGoal], Error> = .success([])
    var fillSavingsGoalsCalls: [(allocations: [(savingsGoalId: String, amount: Decimal)], budgetPeriodId: String, accessToken: String)] = []

    func fillSavingsGoals(allocations: [(savingsGoalId: String, amount: Decimal)], budgetPeriodId: String, accessToken: String) async throws -> [SavingsGoal] {
        fillSavingsGoalsCalls.append((allocations: allocations, budgetPeriodId: budgetPeriodId, accessToken: accessToken))
        return try fillSavingsGoalsResult.get()
    }

    // MARK: - overrideTransactionCategory

    var overrideTransactionCategoryResult: Result<BudgetTransaction, Error> = .success(
        BudgetTransaction(id: UUID(), accountId: UUID(), name: "Test", amount: 10, isoCurrencyCode: "USD", date: "2026-04-01", pending: false, budgetCategory: "flex", categoryOverride: nil, savingsGoalId: nil)
    )

    func overrideTransactionCategory(id: String, budgetCategory: String, savingsGoalId: String?, accessToken: String) async throws -> BudgetTransaction {
        return try overrideTransactionCategoryResult.get()
    }

    // MARK: - withdrawFromSavingsGoals

    var withdrawFromSavingsGoalsCalls: [(withdrawals: [(savingsGoalId: String, amount: Decimal)], budgetPeriodId: String, accessToken: String)] = []

    func withdrawFromSavingsGoals(withdrawals: [(savingsGoalId: String, amount: Decimal)], budgetPeriodId: String, accessToken: String) async throws {
        withdrawFromSavingsGoalsCalls.append((withdrawals: withdrawals, budgetPeriodId: budgetPeriodId, accessToken: accessToken))
    }
}
