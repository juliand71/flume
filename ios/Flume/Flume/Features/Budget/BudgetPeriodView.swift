import SwiftUI
import Supabase

struct BudgetPeriodView: View {
    @Bindable var viewModel: BudgetPeriodViewModel
    @State private var showingFillSheet = false
    @State private var showingWithdrawSheet = false
    @State private var showingSuggestionSheet = false
    @State private var fillViewModel = SavingsGoalViewModel()
    @State private var withdrawViewModel = SavingsGoalViewModel()
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

                        if let carryover = period.carryoverAmount, carryover != 0 {
                            HStack {
                                Text("Carryover")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(carryover, format: .currency(code: "USD"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(carryover >= 0 ? .green : .red)
                            }
                        }

                        if let effectiveSurplus = viewModel.categorySummary?.effectiveSurplus,
                           effectiveSurplus != (period.surplus ?? 0) {
                            HStack {
                                Text("Effective Surplus")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(effectiveSurplus, format: .currency(code: "USD"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(effectiveSurplus >= 0 ? .green : .red)
                            }
                        }

                        if isCurrentPeriod, effectiveSurplusValue(for: period) > 0 {
                            Button {
                                showingFillSheet = true
                            } label: {
                                Label("Fund Goals", systemImage: "arrow.down.to.line")
                            }
                        }

                        if isCurrentPeriod, effectiveSurplusValue(for: period) < 0 {
                            Button {
                                showingWithdrawSheet = true
                            } label: {
                                Label("Withdraw from Goals", systemImage: "arrow.up.from.line")
                            }
                        }
                    }

                    if !allocations.isEmpty {
                        Section(isCurrentPeriod ? "Goal Activity This Period" : "Goal Activity") {
                            ForEach(allocations) { allocation in
                                let isWithdrawal = allocation.type == "withdrawal"
                                HStack {
                                    if let emoji = allocation.goalEmoji {
                                        Text(emoji)
                                    }
                                    Text(allocation.goalName)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: isWithdrawal ? "arrow.up" : "arrow.down")
                                            .font(.caption2)
                                            .foregroundStyle(isWithdrawal ? .orange : .green)
                                        Text(allocation.amount, format: .currency(code: "USD"))
                                            .foregroundStyle(isWithdrawal ? .orange : .secondary)
                                    }
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
                SavingsGoalFillView(viewModel: fillViewModel, surplus: effectiveSurplusValue(for: period), budgetPeriodId: period.id.uuidString)
            }
        }
        .sheet(isPresented: $showingWithdrawSheet, onDismiss: {
            Task {
                await viewModel.refresh()
                await fetchAllocations()
            }
        }) {
            if let period = viewModel.selectedPeriod {
                SavingsGoalWithdrawView(viewModel: withdrawViewModel, deficit: abs(effectiveSurplusValue(for: period)), budgetPeriodId: period.id.uuidString)
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

    private func effectiveSurplusValue(for period: BudgetPeriod) -> Decimal {
        viewModel.categorySummary?.effectiveSurplus ?? period.surplus ?? 0
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
