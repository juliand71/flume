import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @State private var accountsViewModel = AccountsViewModel()
    @State private var budgetViewModel = BudgetPeriodViewModel()
    @State private var savingsGoalViewModel = SavingsGoalViewModel()
    #if DEBUG
    @State private var showDebugSettings = false
    #endif

    var body: some View {
        TabView {
            NavigationStack {
                BudgetPeriodView(viewModel: budgetViewModel)
                    .navigationTitle("Budget")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Sign Out") {
                                Task { try? await authService.signOut() }
                            }
                        }
                        #if DEBUG
                        ToolbarItem(placement: .primaryAction) {
                            Button("Debug", systemImage: "ladybug") {
                                showDebugSettings = true
                            }
                        }
                        #endif
                    }
            }
            .tabItem {
                Label("Budget", systemImage: "chart.pie")
            }

            NavigationStack {
                SavingsGoalListView(viewModel: savingsGoalViewModel)
                    .navigationTitle("Goals")
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }

            NavigationStack {
                AccountsListView(viewModel: accountsViewModel)
                    .navigationTitle("Accounts")
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
                Label("Accounts", systemImage: "building.columns")
            }
        }
        #if DEBUG
        .sheet(isPresented: $showDebugSettings) {
            DebugSettingsView()
        }
        #endif
    }
}
