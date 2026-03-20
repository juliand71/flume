import SwiftUI

struct OnboardingContainerView: View {
    @State var viewModel = OnboardingViewModel()
    @Environment(AuthService.self) private var authService

    let onComplete: () -> Void

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeStepView(viewModel: viewModel)
            case .linkBank:
                #if os(iOS)
                LinkBankStepView(viewModel: viewModel)
                #else
                Text("Plaid Link is only available on iOS.")
                #endif
            case .syncing:
                SyncingStepView(viewModel: viewModel)
            case .confirmIncome:
                IncomeConfirmStepView(viewModel: viewModel)
            case .createBudget:
                BudgetSetupStepView(viewModel: viewModel)
            case .savingsGoal:
                SavingsGoalStepView(viewModel: viewModel, onComplete: onComplete)
            case .complete:
                Color.clear
                    .onAppear { onComplete() }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        .task {
            guard let token = authService.accessToken else { return }
            await viewModel.loadStatus(accessToken: token)
            if viewModel.currentStep == .complete {
                onComplete()
            }
        }
    }
}
