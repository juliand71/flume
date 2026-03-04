import SwiftUI

struct TransactionsListView: View {
    let account: Account
    @State private var viewModel: TransactionsViewModel

    init(account: Account) {
        self.account = account
        self._viewModel = State(initialValue: TransactionsViewModel(accountId: account.id))
    }

    var body: some View {
        Group {
            if viewModel.transactions.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "list.bullet",
                    description: Text("No transactions found for this account.")
                )
            } else {
                List(viewModel.transactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .navigationTitle(account.name)
        .overlay {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.fetchTransactions()
        }
        .task {
            await viewModel.fetchTransactions()
        }
    }
}
