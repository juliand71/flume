import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @State private var accountsViewModel = AccountsViewModel()
    @State private var budgetViewModel = BudgetPeriodViewModel()
    @State private var savingsGoalViewModel = SavingsGoalViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                BudgetPeriodView(viewModel: budgetViewModel)
                    .navigationTitle("Flux")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Sign Out") {
                                Task { try? await authService.signOut() }
                            }
                        }
                    }
            }
            .tabItem {
                Label("Flux", systemImage: "drop.circle")
            }

            NavigationStack {
                SavingsGoalListView(viewModel: savingsGoalViewModel)
                    .navigationTitle("Cistern")
            }
            .tabItem {
                Label("Cistern", systemImage: "cup.and.heat.waves")
            }

            NavigationStack {
                AccountsListView(viewModel: accountsViewModel)
                    .navigationTitle("Basins")
                    .navigationDestination(for: Account.self) { account in
                        TransactionsListView(account: account)
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            PlaidLinkButton(authService: authService)
                        }
                    }
            }
            .tabItem {
                Label("Basins", systemImage: "building.columns")
            }
        }
    }
}
