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
    var periods: [BudgetPeriod] = []
    var selectedPeriod: BudgetPeriod?
    var categorySummary: CategorySummaryResponse?
    var isLoading = false
    var errorMessage: String?
    var suggestions: BudgetSuggestions?

    private var selectedIndex: Int = 0
    private let client = SupabaseService.shared

    var canGoBack: Bool { selectedIndex < periods.count - 1 }
    var canGoForward: Bool { selectedIndex > 0 }

    func navigateBack() async {
        guard canGoBack else { return }
        selectedIndex += 1
        await loadActualsForSelected()
    }

    func navigateForward() async {
        guard canGoForward else { return }
        selectedIndex -= 1
        await loadActualsForSelected()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let accessToken = try await client.auth.session.accessToken
            let (fetched, _) = try await BudgetAPIService.shared.fetchPeriods(accessToken: accessToken)
            periods = fetched // newest-first from API

            // Select the period covering today, or fall back to most recent
            let today = isoDate(Date())
            selectedIndex = periods.firstIndex(where: { $0.startDate <= today && $0.endDate > today }) ?? 0

            await loadActualsForSelected()
            async let summary: () = fetchCategorySummary()
            await summary
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func recalculateBudget() async {
        guard let period = selectedPeriod else { return }
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
        guard let period = selectedPeriod, let suggestions else { return }
        do {
            let accessToken = try await client.auth.session.accessToken
            selectedPeriod = try await BudgetAPIService.shared.updatePeriod(
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

    // MARK: - Private

    private func fetchCategorySummary() async {
        do {
            let accessToken = try await client.auth.session.accessToken
            categorySummary = try await BudgetAPIService.shared.fetchCategorySummary(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadActualsForSelected() async {
        guard !periods.isEmpty else { return }
        do {
            let accessToken = try await client.auth.session.accessToken
            let id = periods[selectedIndex].id.uuidString
            selectedPeriod = try await BudgetAPIService.shared.fetchPeriodById(id, accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func significantlyDifferent(_ detected: Decimal, _ current: Decimal, threshold: Decimal) -> Bool {
        guard current != 0 else { return detected != 0 }
        let diff = abs(detected - current) / abs(current)
        return diff > threshold
    }
}
