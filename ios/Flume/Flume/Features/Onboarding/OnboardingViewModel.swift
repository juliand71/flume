import Foundation

@Observable
final class OnboardingViewModel {
    enum Step: String, CaseIterable {
        case welcome
        case linkBank = "link_bank"
        case syncing
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

    // Confirmed income streams (after user saves them)
    var confirmedStreams: [IncomeStream] = []

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
                        await self?.advanceTo(step: .confirmIncome, accessToken: accessToken)
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
            let response = try await budgetAPI.detectIncome(accessToken: accessToken)
            detectedStreams = response.detectedStreams
            monthlyExpenseEstimate = response.monthlyExpenseEstimate
            dateRangeDays = response.dateRangeDays
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

    // MARK: - Private

    private func nextStep() -> Step? {
        guard let index = Step.allCases.firstIndex(of: currentStep),
              index + 1 < Step.allCases.count else { return nil }
        return Step.allCases[index + 1]
    }
}
