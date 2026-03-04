import Foundation
import Supabase

struct AccountRepository: Sendable {
    private let client = SupabaseService.shared

    func fetchAccounts() async throws -> [Account] {
        try await client.from("accounts")
            .select()
            .order("created_at")
            .execute()
            .value
    }
}
