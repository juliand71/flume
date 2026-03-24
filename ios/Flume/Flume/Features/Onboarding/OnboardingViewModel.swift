import Foundation

@Observable
final class OnboardingViewModel {
    enum Step: String, CaseIterable {
        case welcome
        case linkBank = "link_bank"
        case syncing
        case choosePeriod = "choose_period"
        case confirmIncome = "confirm_income"
        case createBudget = "create_budget"
        case savingsGoal = "savings_goal"
        case complete
    }

    var currentStep: Step = .welcome
    var isLoading = false
    var errorMessage: String?

    // Income detection
    var detectedStreams: [DetectedIncomeStream] = []
    var monthlyExpenseEstimate: Decimal = 0
    var dateRangeDays = 0

    var expandedSearch = false

    // Confirmed income streams (after user saves them)
    var confirmedStreams: [IncomeStream] = []

    // Budget period selection
    var selectedPeriodType: String = "monthly"
    var periodStartDate: Date?
    var periodEndDate: Date?
    var semimonthlyHalf: Int = 1 // 1 = 1st–15th, 2 = 16th–end
    var biweeklyAnchorDate: Date?
    var weeklyStartDay: Int = 2 // 1=Sun..7=Sat, default Mon

    // Budget suggestion
    var budgetSuggestion: BudgetSuggestion?

    private let budgetAPI = BudgetAPIService.shared
    private var pollingTask: Task<Void, Never>?

    func loadStatus(accessToken: String) async {
        do {
            let status = try await budgetAPI.fetchOnboardingStatus(accessToken: accessToken)
            if let step = status.onboardingStep, let s = Step(rawValue: step) {
                currentStep = s
            } else {
                currentStep = .complete
            }
        } catch {
            // If we can't fetch status, assume onboarding complete (don't block existing users)
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
                    let status = try await BudgetAPIService.shared.fetchSyncStatus(accessToken: accessToken)
                    if status.transactionCount > 0 {
                        await self?.advanceTo(step: .choosePeriod, accessToken: accessToken)
                        return
                    }
                } catch {
                    // Ignore polling errors, keep trying
                }
                try? await Task.sleep(for: .seconds(3))
                elapsed += 3
                if elapsed >= 120 {
                    return // Give up after 2 minutes
                }
            }
        }
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
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let start = periodStartDate.map { formatter.string(from: $0) }
            let end = periodEndDate.map { formatter.string(from: $0) }
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

    // MARK: - Budget Suggestion

    func fetchBudgetSuggestion(incomeStreamId: String, accessToken: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            budgetSuggestion = try await budgetAPI.suggestPeriod(
                incomeStreamId: incomeStreamId,
                accessToken: accessToken
            )
        } catch {
            errorMessage = "Failed to get budget suggestion: \(error.localizedDescription)"
        }
    }

    func createBudgetPeriod(
        startDate: String,
        endDate: String,
        incomeTarget: Decimal,
        fixedTarget: Decimal,
        flexTarget: Decimal,
        savingsTarget: Decimal,
        incomeStreamId: String?,
        accessToken: String
    ) async -> Bool {
        do {
            _ = try await budgetAPI.createPeriod(
                startDate: startDate,
                endDate: endDate,
                incomeTarget: incomeTarget,
                fixedTarget: fixedTarget,
                flexTarget: flexTarget,
                savingsTarget: savingsTarget,
                incomeStreamId: incomeStreamId,
                accessToken: accessToken
            )
            return true
        } catch {
            errorMessage = "Failed to create budget: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Savings Goal

    func createEmergencyFund(targetAmount: Decimal, accessToken: String) async -> Bool {
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

    // MARK: - Period Date Computation

    func computePeriodDates() {
        let calendar = Calendar.current
        let today = Date()

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
            // Walk backwards from anchor by 14-day increments to find start <= today
            var start = anchor
            while start > today {
                start = calendar.date(byAdding: .day, value: -14, to: start)!
            }
            periodStartDate = start
            periodEndDate = calendar.date(byAdding: .day, value: 14, to: start)

        case "weekly":
            // Find most recent occurrence of weeklyStartDay on or before today
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
