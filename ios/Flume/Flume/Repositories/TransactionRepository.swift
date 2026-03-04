import Foundation
import Supabase

struct TransactionRepository: Sendable {
    private let client = SupabaseService.shared

    func fetchTransactions(forAccount accountId: UUID) async throws -> [Transaction] {
        try await client.from("transactions")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .order("date", ascending: false)
            .execute()
            .value
    }
}
