import Foundation

@Observable
final class AccountsViewModel {
    var accounts: [Account] = []
    var isLoading = false
    var errorMessage: String?

    private let repository = AccountRepository()

    func fetchAccounts() async {
        isLoading = true
        errorMessage = nil
        do {
            accounts = try await repository.fetchAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
