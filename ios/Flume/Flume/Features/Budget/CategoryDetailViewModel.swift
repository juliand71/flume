import Foundation
import Supabase

@Observable
final class CategoryDetailViewModel {
    var transactions: [BudgetTransaction] = []
    var isLoading = false
    var errorMessage: String?

    let periodId: String
    let category: String

    private let client = SupabaseService.shared

    init(periodId: String, category: String) {
        self.periodId = periodId
        self.category = category
    }

    func fetchTransactions() async {
        isLoading = true
        errorMessage = nil
        do {
            let accessToken = try await client.auth.session.accessToken
            transactions = try await BudgetAPIService.shared.fetchTransactions(
                periodId: periodId,
                category: category,
                accessToken: accessToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func overrideCategory(transactionId: String, newCategory: String) async {
        do {
            let accessToken = try await client.auth.session.accessToken
            _ = try await BudgetAPIService.shared.overrideTransactionCategory(
                id: transactionId,
                budgetCategory: newCategory,
                accessToken: accessToken
            )
            await fetchTransactions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
