import SwiftUI

struct BudgetPeriodView: View {
    @Bindable var viewModel: BudgetPeriodViewModel
    @State private var showingFillSheet = false
    @State private var showingSuggestionSheet = false
    @State private var fillViewModel = SavingsGoalViewModel()
    @State private var allocations: [SavingsGoalAllocation] = []

    private var isCurrentPeriod: Bool {
        guard let period = viewModel.selectedPeriod else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let today = formatter.string(from: Date())
        return period.startDate <= today && period.endDate > today
    }

    var body: some View {
        Group {
            if let period = viewModel.selectedPeriod {
                List {
                    Section {
                        HStack {
                            Button {
                                Task { await viewModel.navigateBack() }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .fontWeight(.semibold)
                            }
                            .disabled(!viewModel.canGoBack)

                            Spacer()

                            Text("\(period.startDate) — \(period.endDate)")
                                .font(.headline)

                            Spacer()

                            Button {
                                Task { await viewModel.navigateForward() }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .fontWeight(.semibold)
                            }
                            .disabled(!viewModel.canGoForward)
                        }
                        .buttonStyle(.plain)
                    }

                    Section {
                        NavigationLink {
                            CategoryDetailView(
                                viewModel: CategoryDetailViewModel(periodId: period.id.uuidString, category: "income"),
                                categoryTitle: "Source",
                                tint: .blue
                            )
                        } label: {
                            CategoryBarView(
                                title: "Source",
                                actual: -(period.actualIncome ?? 0),
                                target: period.incomeTarget,
                                tint: .blue
                            )
                        }
                        NavigationLink {
                            CategoryDetailView(
                                viewModel: CategoryDetailViewModel(periodId: period.id.uuidString, category: "fixed"),
                                categoryTitle: "Fixed",
                                tint: .orange
                            )
                        } label: {
                            CategoryBarView(
                                title: "Fixed",
                                actual: period.actualFixed ?? 0,
                                target: period.fixedTarget,
                                tint: .orange
                            )
                        }
                        NavigationLink {
                            CategoryDetailView(
                                viewModel: CategoryDetailViewModel(periodId: period.id.uuidString, category: "flex"),
                                categoryTitle: "Flex",
                                tint: .purple
                            )
                        } label: {
                            CategoryBarView(
                                title: "Flex",
                                actual: period.actualFlex ?? 0,
                                target: period.flexTarget,
                                tint: .purple
                            )
                        }
                    }

                    Section {
                        HStack {
                            Text("Surplus")
                                .font(.headline)
                            Spacer()
                            Text(period.surplus ?? 0, format: .currency(code: "USD"))
                                .font(.title2.weight(.semibold))
                                .foregroundStyle((period.surplus ?? 0) >= 0 ? .green : .red)
                        }
                        .padding(.vertical, 4)

                        if isCurrentPeriod, (period.surplus ?? 0) > 0 {
                            Button {
                                showingFillSheet = true
                            } label: {
                                Label("Fund Goals", systemImage: "arrow.down.to.line")
                            }
                        }
                    }

                    if !allocations.isEmpty {
                        Section(isCurrentPeriod ? "Funded This Period" : "Funded Goals") {
                            ForEach(allocations) { allocation in
                                HStack {
                                    if let emoji = allocation.goalEmoji {
                                        Text(emoji)
                                    }
                                    Text(allocation.goalName)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(allocation.amount, format: .currency(code: "USD"))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView(
                    "No Active Budget",
                    systemImage: "chart.pie",
                    description: Text("Create a budget period to get started.")
                )
            }
        }
        .sheet(isPresented: $showingFillSheet, onDismiss: {
            Task {
                await viewModel.refresh()
                await fetchAllocations()
            }
        }) {
            if let period = viewModel.selectedPeriod {
                SavingsGoalFillView(viewModel: fillViewModel, surplus: period.surplus ?? 0, budgetPeriodId: period.id.uuidString)
            }
        }
        .onChange(of: viewModel.selectedPeriod?.id) {
            Task { await fetchAllocations() }
        }
        .sheet(isPresented: $showingSuggestionSheet) {
            BudgetUpdateSuggestionView(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetRecalculationNeeded)) { _ in
            Task {
                await viewModel.recalculateBudget()
                if viewModel.suggestions != nil {
                    showingSuggestionSheet = true
                }
            }
        }
    }

    private func fetchAllocations() async {
        guard let period = viewModel.selectedPeriod else {
            allocations = []
            return
        }
        do {
            let accessToken = try await SupabaseService.shared.auth.session.accessToken
            allocations = try await BudgetAPIService.shared.fetchAllocations(
                periodId: period.id.uuidString, accessToken: accessToken
            )
        } catch {
            allocations = []
        }
    }
}
