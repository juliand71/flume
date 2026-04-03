import Testing
import Foundation
@testable import Flume

@Suite("Onboarding Fixed Expense Detection")
struct OnboardingFixedTests {

    private func makeVM() -> (OnboardingViewModel, MockBudgetAPIService) {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        // Pin date and compute monthly dates so periodStartDate/periodEndDate are set
        vm.dateProvider = {
            var c = DateComponents()
            c.year = 2026; c.month = 4; c.day = 10; c.hour = 12
            return Calendar.current.date(from: c)!
        }
        vm.selectedPeriodType = "monthly"
        vm.computePeriodDates()
        return (vm, mock)
    }

    @Test("detectFixed populates expenses and confirmedFixedTotal")
    func detectFixedPopulates() async {
        let (vm, mock) = makeVM()
        let expenses = FixedExpenseFactory.typicalExpenses()
        mock.detectFixedResult = .success(
            FixedExpenseFactory.detectionResponse(expenses: expenses, totalFixed: 1750)
        )

        await vm.detectFixed(accessToken: "token")

        #expect(vm.detectedFixedExpenses.count == 4)
        #expect(vm.confirmedFixedTotal == 1750)
    }

    @Test("detectFixed sets isLoading to false after completion")
    func loadingLifecycle() async {
        let (vm, mock) = makeVM()
        mock.detectFixedResult = .success(FixedExpenseFactory.detectionResponse())

        await vm.detectFixed(accessToken: "token")

        #expect(vm.isLoading == false)
    }

    @Test("detectFixed error sets errorMessage")
    func detectFixedError() async {
        let (vm, mock) = makeVM()
        mock.detectFixedResult = .failure(NSError(domain: "test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Boom"]))

        await vm.detectFixed(accessToken: "token")

        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage?.contains("fixed") == true)
    }

    @Test("detectFixed with nil period dates returns early without API call")
    func nilPeriodDatesEarlyReturn() async {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        // Do NOT set period dates

        await vm.detectFixed(accessToken: "token")

        #expect(mock.detectFixedCalls.isEmpty)
        #expect(vm.detectedFixedExpenses.isEmpty)
    }

    @Test("User adjustment to confirmedFixedTotal cascades to projectedSavings")
    func fixedAdjustmentAffectsSavings() {
        let (vm, _) = makeVM()
        vm.confirmedIncomeTotal = 5000
        vm.confirmedFixedTotal = 1500
        vm.confirmedFlexTarget = 800

        #expect(vm.projectedSavings == 2700)

        vm.confirmedFixedTotal = 2000

        #expect(vm.projectedSavings == 2200)
    }
}
