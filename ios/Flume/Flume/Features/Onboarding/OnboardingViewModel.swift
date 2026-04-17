import Foundation

@Observable
final class OnboardingViewModel {
    enum Step: String, CaseIterable {
        case welcome
        case linkBank = "link_bank"
        case syncing
        case choosePeriod = "choose_period"
        case confirmIncome = "confirm_income"
        case confirmFixed = "confirm_fixed"
        case confirmFlex = "confirm_flex"
        case reviewSavings = "review_savings"
        case savingsGoal = "savings_goal"
        case complete
    }

    var currentStep: Step = .welcome
    var isLoading = false
    var errorMessage: String?

    // Multi-bank linking
    var hasSyncedTransactions = false
    var linkedInstitutionNames: [String] = []

    // Income detection
    var detectedStreams: [DetectedIncomeStream] = []
    var monthlyExpenseEstimate: Decimal = 0
    var dateRangeDays = 0
    var expandedSearch = false

    // Confirmed income streams (after user saves them)
    var confirmedStreams: [IncomeStream] = []
    var confirmedIncomeTotal: Decimal = 0

    // Fixed spending detection
    var detectedFixedExpenses: [DetectedFixedExpense] = []
    var confirmedFixedTotal: Decimal = 0

    // Flex spending detection
    var detectedFlexTotal: Decimal = 0
    var confirmedFlexTarget: Decimal = 0
    var flexTransactionCount: Int = 0

    // Budget period selection
    var selectedPeriodType: String = "monthly"
    var periodStartDate: Date?
    var periodEndDate: Date?
    var semimonthlyHalf: Int = 1 // 1 = 1st–15th, 2 = 16th–end
    var createdPeriodId: String?
    var biweeklyAnchorDate: Date?
    var weeklyStartDay: Int = 2 // 1=Sun..7=Sat, default Mon

    private let budgetAPI: BudgetAPIServiceProtocol
    private var pollingTask: Task<Void, Never>?
    var dateProvider: () -> Date = { Date() }

    init(budgetAPI: BudgetAPIServiceProtocol = BudgetAPIService.shared) {
        self.budgetAPI = budgetAPI
    }

    // MARK: - Computed

    var projectedSavings: Decimal {
        confirmedIncomeTotal - confirmedFixedTotal - confirmedFlexTarget
    }

    var periodStartDateString: String? {
        periodStartDate.map { formatDate($0) }
    }

    var periodEndDateString: String? {
        periodEndDate.map { formatDate($0) }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Onboarding Status

    func loadStatus(accessToken: String) async {
        do {
            let status = try await budgetAPI.fetchOnboardingStatus(accessToken: accessToken)
            if let step = status.onboardingStep, let s = Step(rawValue: step) {
                currentStep = s
            } else {
                currentStep = .complete
            }
        } catch {
            currentStep = .complete
        }
    }

    func advanceStep(accessToken: String) async {
        guard let nextStep = nextStep() else { return }
        do {
            let status = try await budgetAPI.updateOnboardingStep(step: nextStep.rawValue, accessToken: accessToken)
            if let step = status.onboardingStep, let s = Step(rawValue: step) {
                currentStep = s
            }
        } catch {
            errorMessage = "Failed to advance: \(error.localizedDescription)"
        }
    }

    func advanceTo(step: Step, accessToken: String) async {
        do {
            let status = try await budgetAPI.updateOnboardingStep(step: step.rawValue, accessToken: accessToken)
            if let s = status.onboardingStep.flatMap({ Step(rawValue: $0) }) {
                currentStep = s
            }
        } catch {
            errorMessage = "Failed to advance: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync Polling

    func startPollingSync(accessToken: String) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            var elapsed = 0
            while !Task.isCancelled {
                do {
                    guard let self else { return }
                    let status = try await self.budgetAPI.fetchSyncStatus(accessToken: accessToken)
                    if status.transactionCount > 0 {
                        self.hasSyncedTransactions = true
                        return
                    }
                } catch {
                    // Ignore polling errors, keep trying
                }
                try? await Task.sleep(for: .seconds(3))
                elapsed += 3
                if elapsed >= 120 {
                    return
                }
            }
        }
    }

    func restartPollingSync(accessToken: String) {
        hasSyncedTransactions = false
        startPollingSync(accessToken: accessToken)
    }

    func stopPollingSync() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Income Detection

    func detectIncome(accessToken: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let start = periodStartDateString
            let end = periodEndDateString
            let response = try await budgetAPI.detectIncome(startDate: start, endDate: end, accessToken: accessToken)
            detectedStreams = response.detectedStreams
            monthlyExpenseEstimate = response.monthlyExpenseEstimate
            dateRangeDays = response.dateRangeDays
            expandedSearch = response.expandedSearch ?? false
        } catch {
            errorMessage = "Failed to detect income: \(error.localizedDescription)"
        }
    }

    func confirmIncomeStream(
        name: String,
        estimatedAmount: Decimal,
        frequency: String,
        nextExpectedDate: String?,
        accessToken: String
    ) async -> IncomeStream? {
        do {
            let stream = try await budgetAPI.createIncomeStream(
                name: name,
                estimatedAmount: estimatedAmount,
                frequency: frequency,
                nextExpectedDate: nextExpectedDate,
                accessToken: accessToken
            )
            confirmedStreams.append(stream)
            return stream
        } catch {
            errorMessage = "Failed to save income stream: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Fixed Spending Detection

    func detectFixed(accessToken: String) async {
        guard let start = periodStartDateString, let end = periodEndDateString else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await budgetAPI.detectFixed(startDate: start, endDate: end, accessToken: accessToken)
            detectedFixedExpenses = response.detectedExpenses
            confirmedFixedTotal = response.totalFixed
        } catch {
            errorMessage = "Failed to detect fixed expenses: \(error.localizedDescription)"
        }
    }

    // MARK: - Flex Spending Detection

    func detectFlex(accessToken: String) async {
        guard let start = periodStartDateString, let end = periodEndDateString else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await budgetAPI.detectFlex(startDate: start, endDate: end, accessToken: accessToken)
            detectedFlexTotal = response.totalFlex
            confirmedFlexTarget = response.totalFlex
            flexTransactionCount = response.transactionCount
        } catch {
            errorMessage = "Failed to detect flex spending: \(error.localizedDescription)"
        }
    }

    // MARK: - Budget Creation

    func createBudgetFromConfirmedValues(accessToken: String) async -> Bool {
        guard let start = periodStartDateString, let end = periodEndDateString else { return false }
        do {
            let period = try await budgetAPI.createPeriod(
                startDate: start,
                endDate: end,
                incomeTarget: confirmedIncomeTotal,
                fixedTarget: confirmedFixedTotal,
                flexTarget: confirmedFlexTarget,
                savingsTarget: projectedSavings,
                incomeStreamId: confirmedStreams.first?.id.uuidString,
                accessToken: accessToken
            )
            createdPeriodId = period.id.uuidString
            return true
        } catch {
            errorMessage = "Failed to create budget: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Savings Goal

    var savingsAccountBalance: Decimal = 0
    var createdEmergencyFundTarget: Decimal = 0

    var unallocatedSavings: Decimal {
        max(savingsAccountBalance - createdEmergencyFundTarget, 0)
    }

    func fetchSavingsBalance(accessToken: String) async {
        do {
            let accounts = try await budgetAPI.fetchAccounts(accessToken: accessToken)
            let savingsAccounts = accounts.filter { $0.accountRole == "savings" }
            let relevant = savingsAccounts.isEmpty
                ? accounts.filter { $0.accountRole != "credit_card" }
                : savingsAccounts
            savingsAccountBalance = relevant.compactMap { $0.currentBalance }.reduce(0, +)
        } catch {
            savingsAccountBalance = 0
        }
    }

    func createEmergencyFund(targetAmount: Decimal, accessToken: String) async -> Bool {
        createdEmergencyFundTarget = targetAmount
        do {
            _ = try await budgetAPI.createSavingsGoal(
                name: "Emergency Fund",
                targetAmount: targetAmount,
                emoji: "🛟",
                isEmergencyFund: true,
                priority: 0,
                accessToken: accessToken
            )
            return true
        } catch {
            errorMessage = "Failed to create emergency fund: \(error.localizedDescription)"
            return false
        }
    }

    func createAndFillAdditionalGoals(
        drafts: [(name: String, emoji: String?, targetAmount: Decimal, fillAmount: Decimal?)],
        accessToken: String
    ) async -> Bool {
        do {
            var allocations: [(savingsGoalId: String, amount: Decimal)] = []
            for draft in drafts {
                let goal = try await budgetAPI.createSavingsGoal(
                    name: draft.name,
                    targetAmount: draft.targetAmount,
                    emoji: draft.emoji,
                    isEmergencyFund: false,
                    priority: 1,
                    accessToken: accessToken
                )
                if let fill = draft.fillAmount, fill > 0 {
                    allocations.append((savingsGoalId: goal.id.uuidString, amount: fill))
                }
            }
            if !allocations.isEmpty, let periodId = createdPeriodId {
                _ = try await budgetAPI.fillSavingsGoals(allocations: allocations, budgetPeriodId: periodId, accessToken: accessToken)
            }
            return true
        } catch {
            errorMessage = "Failed to create goals: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Period Date Computation

    func computePeriodDates() {
        let calendar = Calendar.current
        let today = dateProvider()

        switch selectedPeriodType {
        case "monthly":
            let components = calendar.dateComponents([.year, .month], from: today)
            periodStartDate = calendar.date(from: components)
            periodEndDate = calendar.date(byAdding: .month, value: 1, to: periodStartDate!)

        case "semimonthly":
            let components = calendar.dateComponents([.year, .month], from: today)
            let firstOfMonth = calendar.date(from: components)!
            if semimonthlyHalf == 1 {
                periodStartDate = firstOfMonth
                periodEndDate = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 16))
            } else {
                periodStartDate = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 16))
                periodEndDate = calendar.date(byAdding: .month, value: 1, to: firstOfMonth)
            }

        case "biweekly":
            guard let anchor = biweeklyAnchorDate else { return }
            var start = anchor
            if start > today {
                while start > today {
                    start = calendar.date(byAdding: .day, value: -14, to: start)!
                }
            } else {
                while calendar.date(byAdding: .day, value: 14, to: start)! <= today {
                    start = calendar.date(byAdding: .day, value: 14, to: start)!
                }
            }
            periodStartDate = start
            periodEndDate = calendar.date(byAdding: .day, value: 14, to: start)

        case "weekly":
            let todayWeekday = calendar.component(.weekday, from: today)
            var daysBack = todayWeekday - weeklyStartDay
            if daysBack < 0 { daysBack += 7 }
            periodStartDate = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: today))
            periodEndDate = calendar.date(byAdding: .day, value: 7, to: periodStartDate!)

        default:
            break
        }
    }

    // MARK: - Private

    private func nextStep() -> Step? {
        guard let index = Step.allCases.firstIndex(of: currentStep),
              index + 1 < Step.allCases.count else { return nil }
        return Step.allCases[index + 1]
    }
}
