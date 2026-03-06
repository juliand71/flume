import SwiftUI

struct AccountsListView: View {
    @Bindable var viewModel: AccountsViewModel

    var body: some View {
        Group {
            if viewModel.accounts.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "building.columns",
                    description: Text("Link a bank account to get started.")
                )
            } else {
                List(viewModel.accounts) { account in
                    NavigationLink(value: account) {
                        AccountRow(account: account)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.accounts.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.fetchAccounts()
        }
        .task {
            await viewModel.fetchAccounts()
            await viewModel.syncAllItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountsDidChange)) { _ in
            Task { await viewModel.fetchAccounts() }
        }
    }
}

extension Notification.Name {
    static let accountsDidChange = Notification.Name("accountsDidChange")
}
