import SwiftUI

struct BudgetPeriodView: View {
    @Bindable var viewModel: BudgetPeriodViewModel
    @State private var showingFillSheet = false
    @State private var fillViewModel = SavingsGoalViewModel()

    var body: some View {
        Group {
            if let period = viewModel.currentPeriod {
                List {
                    Section {
                        Text("\(period.startDate) — \(period.endDate)")
                            .font(.headline)
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
                                actual: period.actualIncome ?? 0,
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
                            Text("Spillover")
                                .font(.headline)
                            Spacer()
                            Text(period.surplus ?? 0, format: .currency(code: "USD"))
                                .font(.title2.weight(.semibold))
                                .foregroundStyle((period.surplus ?? 0) >= 0 ? .green : .red)
                        }
                        .padding(.vertical, 4)

                        if (period.surplus ?? 0) > 0 {
                            Button {
                                showingFillSheet = true
                            } label: {
                                Label("Fill Buckets", systemImage: "arrow.down.to.line")
                            }
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView(
                    "No Active Flux",
                    systemImage: "drop.circle",
                    description: Text("Create a budget period to get started.")
                )
            }
        }
        .sheet(isPresented: $showingFillSheet) {
            if let period = viewModel.currentPeriod {
                SavingsGoalFillView(viewModel: fillViewModel, surplus: period.surplus ?? 0)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
    }
}
