import Foundation

protocol BudgetAPIServiceProtocol: Sendable {
    func fetchOnboardingStatus(accessToken: String) async throws -> OnboardingStatus
    func updateOnboardingStep(step: String, accessToken: String) async throws -> OnboardingStatus
    func fetchSyncStatus(accessToken: String) async throws -> SyncStatus
    func detectIncome(startDate: String?, endDate: String?, accessToken: String) async throws -> IncomeDetectionResponse
    func detectFixed(startDate: String, endDate: String, accessToken: String) async throws -> FixedDetectionResponse
    func detectFlex(startDate: String, endDate: String, accessToken: String) async throws -> FlexDetectionResponse
    func createIncomeStream(name: String, estimatedAmount: Decimal, frequency: String, nextExpectedDate: String?, accessToken: String) async throws -> IncomeStream
    func createPeriod(startDate: String, endDate: String, incomeTarget: Decimal, fixedTarget: Decimal, flexTarget: Decimal, savingsTarget: Decimal, incomeStreamId: String?, accessToken: String) async throws -> BudgetPeriod
    func createSavingsGoal(name: String, targetAmount: Decimal, emoji: String?, isEmergencyFund: Bool, priority: Int, accessToken: String) async throws -> SavingsGoal
    func fetchAccounts(accessToken: String) async throws -> [Account]
    func fillSavingsGoals(allocations: [(savingsGoalId: String, amount: Decimal)], accessToken: String) async throws -> [SavingsGoal]
}

extension BudgetAPIService: BudgetAPIServiceProtocol {}
