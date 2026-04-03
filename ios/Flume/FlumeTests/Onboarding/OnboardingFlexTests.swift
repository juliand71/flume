import Testing
import Foundation
@testable import Flume

@Suite("Onboarding Flex Spending Detection")
struct OnboardingFlexTests {

    private func makeVM() -> (OnboardingViewModel, MockBudgetAPIService) {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        vm.dateProvider = {
            var c = DateComponents()
            c.year = 2026; c.month = 4; c.day = 10; c.hour = 12
            return Calendar.current.date(from: c)!
        }
        vm.selectedPeriodType = "monthly"
        vm.computePeriodDates()
        return (vm, mock)
    }

    @Test("detectFlex sets detectedFlexTotal and confirmedFlexTarget")
    func detectFlexPopulates() async {
        let (vm, mock) = makeVM()
        mock.detectFlexResult = .success(FlexFactory.detectionResponse(totalFlex: 950, transactionCount: 85))

        await vm.detectFlex(accessToken: "token")

        #expect(vm.detectedFlexTotal == 950)
        #expect(vm.confirmedFlexTarget == 950)
    }

    @Test("detectFlex sets flexTransactionCount")
    func flexTransactionCountSet() async {
        let (vm, mock) = makeVM()
        mock.detectFlexResult = .success(FlexFactory.detectionResponse(totalFlex: 600, transactionCount: 72))

        await vm.detectFlex(accessToken: "token")

        #expect(vm.flexTransactionCount == 72)
    }

    @Test("detectFlex with nil dates returns early without API call")
    func nilDatesEarlyReturn() async {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        // No period dates set

        await vm.detectFlex(accessToken: "token")

        #expect(mock.detectFlexCalls.isEmpty)
        #expect(vm.detectedFlexTotal == 0)
    }

    @Test("User adjusting confirmedFlexTarget affects projectedSavings")
    func flexAdjustmentAffectsSavings() {
        let (vm, _) = makeVM()
        vm.confirmedIncomeTotal = 5000
        vm.confirmedFixedTotal = 1500
        vm.confirmedFlexTarget = 800

        #expect(vm.projectedSavings == 2700)

        vm.confirmedFlexTarget = 1200

        #expect(vm.projectedSavings == 2300)
    }
}
