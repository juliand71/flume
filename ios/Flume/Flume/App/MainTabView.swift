import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = AccountsViewModel()

    var body: some View {
        NavigationStack {
            AccountsListView(viewModel: viewModel)
                .navigationTitle("Accounts")
                .navigationDestination(for: Account.self) { account in
                    TransactionsListView(account: account)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        PlaidLinkButton(authService: authService)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Sign Out") {
                            Task { try? await authService.signOut() }
                        }
                    }
                }
        }
    }
}
