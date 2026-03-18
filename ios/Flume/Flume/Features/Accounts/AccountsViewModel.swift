import Foundation
import Supabase

@Observable
final class AccountsViewModel {
    var accounts: [Account] = []
    var isLoading = false
    var errorMessage: String?

    private let client = SupabaseService.shared
    private var isSyncing = false

    func fetchAccounts() async {
        isLoading = true
        errorMessage = nil
        do {
            let accessToken = try await client.auth.session.accessToken
            accounts = try await BudgetAPIService.shared.fetchAccounts(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func syncAllItems() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let accessToken = try await client.auth.session.accessToken

            let items: [PlaidItem] = try await client.from("plaid_items")
                .select("id, user_id, plaid_item_id, institution_name, created_at")
                .execute()
                .value

            for item in items {
                try await APIService.shared.syncTransactions(
                    plaidItemId: item.id.uuidString,
                    accessToken: accessToken
                )
            }

            await fetchAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
