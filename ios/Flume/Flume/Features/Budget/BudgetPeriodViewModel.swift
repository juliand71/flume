import Foundation
import Supabase

struct BudgetSuggestions {
    let incomeTarget: Decimal?
    let fixedTarget: Decimal?
    let flexTarget: Decimal?
    let savingsTarget: Decimal?

    var isEmpty: Bool {
        incomeTarget == nil && fixedTarget == nil && flexTarget == nil && savingsTarget == nil
    }
}

@Observable
final class BudgetPeriodViewModel {
    var currentPeriod: BudgetPeriod?
    var categorySummary: CategorySummaryResponse?
    var isLoading = false
    var errorMessage: String?
    var suggestions: BudgetSuggestions?

    private let client = SupabaseService.shared

    func fetchCurrentPeriod() async {
        isLoading = true
        errorMessage = nil
        do {
            let accessToken = try await client.auth.session.accessToken
            currentPeriod = try await BudgetAPIService.shared.fetchCurrentPeriod(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchCategorySummary() async {
        do {
            let accessToken = try await client.auth.session.accessToken
            categorySummary = try await BudgetAPIService.shared.fetchCategorySummary(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await fetchCurrentPeriod()
        await fetchCategorySummary()
    }

    func recalculateBudget() async {
        guard let period = currentPeriod else { return }
        do {
            let accessToken = try await client.auth.session.accessToken
            let api = BudgetAPIService.shared

            let income = try await api.detectIncome(
                startDate: period.startDate,
                endDate: period.endDate,
                accessToken: accessToken
            )
            let fixed = try await api.detectFixed(
                startDate: period.startDate,
                endDate: period.endDate,
                accessToken: accessToken
            )
            let flex = try await api.detectFlex(
                startDate: period.startDate,
                endDate: period.endDate,
                accessToken: accessToken
            )

            let detectedIncome = income.detectedStreams.reduce(Decimal.zero) { $0 + ($1.periodAmount ?? $1.estimatedAmount) }
            let detectedFixed = fixed.totalFixed
            let detectedFlex = flex.totalFlex
            let detectedSavings = detectedIncome - detectedFixed - detectedFlex

            let threshold: Decimal = 0.05
            let suggestedIncome = significantlyDifferent(detectedIncome, period.incomeTarget, threshold: threshold) ? detectedIncome : nil
            let suggestedFixed = significantlyDifferent(detectedFixed, period.fixedTarget, threshold: threshold) ? detectedFixed : nil
            let suggestedFlex = significantlyDifferent(detectedFlex, period.flexTarget, threshold: threshold) ? detectedFlex : nil
            let suggestedSavings = significantlyDifferent(detectedSavings, period.savingsTarget, threshold: threshold) ? detectedSavings : nil

            let result = BudgetSuggestions(
                incomeTarget: suggestedIncome,
                fixedTarget: suggestedFixed,
                flexTarget: suggestedFlex,
                savingsTarget: suggestedSavings
            )

            if !result.isEmpty {
                suggestions = result
            }
        } catch {
            // Detection failure is non-critical; don't surface to user
        }
    }

    func applySuggestions() async {
        guard let period = currentPeriod, let suggestions else { return }
        do {
            let accessToken = try await client.auth.session.accessToken
            currentPeriod = try await BudgetAPIService.shared.updatePeriod(
                id: period.id.uuidString,
                incomeTarget: suggestions.incomeTarget,
                fixedTarget: suggestions.fixedTarget,
                flexTarget: suggestions.flexTarget,
                savingsTarget: suggestions.savingsTarget,
                accessToken: accessToken
            )
            self.suggestions = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissSuggestions() {
        suggestions = nil
    }

    private func significantlyDifferent(_ detected: Decimal, _ current: Decimal, threshold: Decimal) -> Bool {
        guard current != 0 else { return detected != 0 }
        let diff = abs(detected - current) / abs(current)
        return diff > threshold
    }
}
