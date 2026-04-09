import SwiftUI

struct SavingsGoalStepView: View {
    let viewModel: OnboardingViewModel
    let onComplete: () -> Void
    @Environment(AuthService.self) private var authService

    @State private var targetAmount = ""
    @State private var isSaving = false
    @State private var phase: Phase = .emergencyFund
    @State private var draftGoals: [DraftGoal] = [DraftGoal()]

    private enum Phase { case emergencyFund, additionalGoals }

    struct DraftGoal: Identifiable {
        let id = UUID()
        var name: String = ""
        var emoji: String = ""
        var targetAmount: String = ""
        var fillAmount: String = ""
    }

    var body: some View {
        switch phase {
        case .emergencyFund:
            emergencyFundView
        case .additionalGoals:
            additionalGoalsView
        }
    }

    // MARK: - Phase 1: Emergency Fund

    private var emergencyFundView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lifepreserver")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Emergency Fund")
                .font(.title.bold())

            Text("Financial experts recommend saving 3–6 months of expenses. We'll help you get there.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Target Amount")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("$")
                    TextField("0.00", text: $targetAmount)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                .textFieldStyle(.roundedBorder)

                if viewModel.monthlyExpenseEstimate > 0 {
                    let threeMonths = viewModel.monthlyExpenseEstimate * 3
                    let sixMonths = viewModel.monthlyExpenseEstimate * 6
                    Text("Based on your spending: $\(threeMonths) – $\(sixMonths)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task { await createFund() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Emergency Fund")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(targetAmount.isEmpty || isSaving)

            Button("Skip for Now") {
                Task { await skipAndComplete() }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: 400)
        .onAppear {
            if viewModel.monthlyExpenseEstimate > 0 {
                let suggested = viewModel.monthlyExpenseEstimate * 3
                targetAmount = "\(suggested)"
            }
        }
    }

    // MARK: - Phase 2: Additional Goals

    private var additionalGoalsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    Text("Organise Your Savings")
                        .font(.title.bold())

                    Text("You have \(viewModel.unallocatedSavings, format: .currency(code: "USD")) beyond your emergency fund. Want to put it to work?")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                HStack {
                    Text("Available to allocate")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.unallocatedSavings, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal)

                if totalFillAmount > viewModel.unallocatedSavings {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Pre-fill total exceeds available savings")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    ForEach($draftGoals) { $goal in
                        DraftGoalRow(goal: $goal)
                    }
                }
                .padding(.horizontal)

                Button {
                    draftGoals.append(DraftGoal())
                } label: {
                    Label("Add Goal", systemImage: "plus.circle")
                }
                .foregroundStyle(.tint)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await saveAdditionalGoals() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSaving || !hasValidDrafts || totalFillAmount > viewModel.unallocatedSavings)

                    Button("Skip for Now") {
                        Task { await finishOnboarding() }
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .frame(maxWidth: 400)
    }

    private var hasValidDrafts: Bool {
        draftGoals.contains { !$0.name.isEmpty && !$0.targetAmount.isEmpty && Decimal(string: $0.targetAmount) != nil }
    }

    private var totalFillAmount: Decimal {
        draftGoals.compactMap { Decimal(string: $0.fillAmount) }.reduce(0, +)
    }

    // MARK: - Actions

    private func createFund() async {
        guard let token = authService.accessToken else { return }
        guard let amount = Decimal(string: targetAmount), amount > 0 else { return }
        isSaving = true
        defer { isSaving = false }

        let success = await viewModel.createEmergencyFund(targetAmount: amount, accessToken: token)
        if success {
            await viewModel.fetchSavingsBalance(accessToken: token)
            if viewModel.unallocatedSavings > 0 {
                phase = .additionalGoals
            } else {
                await finishOnboarding()
            }
        }
    }

    private func saveAdditionalGoals() async {
        guard let token = authService.accessToken else { return }
        isSaving = true
        defer { isSaving = false }

        let drafts: [(name: String, emoji: String?, targetAmount: Decimal, fillAmount: Decimal?)] = draftGoals.compactMap { draft in
            guard !draft.name.isEmpty, let target = Decimal(string: draft.targetAmount), target > 0 else { return nil }
            let fill = Decimal(string: draft.fillAmount).flatMap { $0 > 0 ? $0 : nil }
            return (name: draft.name, emoji: draft.emoji.isEmpty ? nil : draft.emoji, targetAmount: target, fillAmount: fill)
        }

        guard !drafts.isEmpty else {
            await finishOnboarding()
            return
        }

        let success = await viewModel.createAndFillAdditionalGoals(drafts: drafts, accessToken: token)
        if success {
            await finishOnboarding()
        }
    }

    private func skipAndComplete() async {
        guard let token = authService.accessToken else { return }
        await viewModel.advanceTo(step: .complete, accessToken: token)
        onComplete()
    }

    private func finishOnboarding() async {
        guard let token = authService.accessToken else { return }
        await viewModel.advanceTo(step: .complete, accessToken: token)
        onComplete()
    }
}

// MARK: - Draft Goal Row

private struct DraftGoalRow: View {
    @Binding var goal: SavingsGoalStepView.DraftGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("🎯", text: $goal.emoji)
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                    .onChange(of: goal.emoji) { _, newValue in
                        if newValue.count > 1 { goal.emoji = String(newValue.suffix(1)) }
                    }
                    .textFieldStyle(.roundedBorder)

                TextField("Goal name (e.g. Vacation)", text: $goal.name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("$")
                        TextField("0.00", text: $goal.targetAmount)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pre-fill (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("$")
                        TextField("0.00", text: $goal.fillAmount)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
