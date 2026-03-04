import Foundation

@Observable
final class TransactionsViewModel {
    var transactions: [Transaction] = []
    var isLoading = false
    var errorMessage: String?

    private let repository = TransactionRepository()
    private let accountId: UUID

    init(accountId: UUID) {
        self.accountId = accountId
    }

    func fetchTransactions() async {
        isLoading = true
        errorMessage = nil
        do {
            transactions = try await repository.fetchTransactions(forAccount: accountId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
