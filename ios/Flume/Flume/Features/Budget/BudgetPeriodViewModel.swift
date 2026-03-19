import Foundation
import Supabase

@Observable
final class BudgetPeriodViewModel {
    var currentPeriod: BudgetPeriod?
    var categorySummary: CategorySummaryResponse?
    var isLoading = false
    var errorMessage: String?

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
}
