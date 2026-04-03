import Testing
import Foundation
@testable import Flume

@Suite("Onboarding Step Navigation")
struct OnboardingStepNavTests {

    private func makeVM() -> (OnboardingViewModel, MockBudgetAPIService) {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        return (vm, mock)
    }

    @Test("Initial step is .welcome")
    func initialStep() {
        let (vm, _) = makeVM()
        #expect(vm.currentStep == .welcome)
    }

    @Test("loadStatus happy path sets currentStep from server response")
    func loadStatusHappyPath() async {
        let (vm, mock) = makeVM()
        mock.fetchOnboardingStatusResult = .success(
            BudgetPeriodFactory.onboardingStatus(step: "confirm_income")
        )

        await vm.loadStatus(accessToken: "token")

        #expect(vm.currentStep == .confirmIncome)
    }

    @Test("loadStatus with nil step sets currentStep to .complete")
    func loadStatusNilStep() async {
        let (vm, mock) = makeVM()
        mock.fetchOnboardingStatusResult = .success(
            BudgetPeriodFactory.onboardingStatus(step: nil)
        )

        await vm.loadStatus(accessToken: "token")

        #expect(vm.currentStep == .complete)
    }

    @Test("loadStatus error sets currentStep to .complete")
    func loadStatusError() async {
        let (vm, mock) = makeVM()
        mock.fetchOnboardingStatusResult = .failure(NSError(domain: "test", code: 500))

        await vm.loadStatus(accessToken: "token")

        #expect(vm.currentStep == .complete)
    }

    @Test("advanceStep moves to the next step")
    func advanceStepProgression() async {
        let (vm, mock) = makeVM()
        // Start at welcome, advance should call updateOnboardingStep with "link_bank"
        mock.updateOnboardingStepResult = .success(
            BudgetPeriodFactory.onboardingStatus(step: "link_bank")
        )

        await vm.advanceStep(accessToken: "token")

        #expect(vm.currentStep == .linkBank)
        #expect(mock.updateOnboardingStepCalls.count == 1)
        #expect(mock.updateOnboardingStepCalls[0].step == "link_bank")
    }

    @Test("advanceStep at terminal state (.complete) is a no-op")
    func advanceStepAtComplete() async {
        let (vm, mock) = makeVM()
        vm.currentStep = .complete

        await vm.advanceStep(accessToken: "token")

        #expect(vm.currentStep == .complete)
        #expect(mock.updateOnboardingStepCalls.isEmpty)
    }

    @Test("Step.allCases ordering contract")
    func stepOrderingContract() {
        let allCases = OnboardingViewModel.Step.allCases
        let expected: [OnboardingViewModel.Step] = [
            .welcome, .linkBank, .syncing, .choosePeriod,
            .confirmIncome, .confirmFixed, .confirmFlex,
            .reviewSavings, .savingsGoal, .complete
        ]
        #expect(allCases == expected)
    }
}
