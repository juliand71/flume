import Testing
import Foundation
@testable import Flume

@Suite("Onboarding Budget Calculations")
struct OnboardingBudgetCalcTests {

    private func makeVM() -> (OnboardingViewModel, MockBudgetAPIService) {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        return (vm, mock)
    }

    // MARK: - projectedSavings

    struct SavingsCase: Sendable, CustomTestStringConvertible {
        let income: Decimal
        let fixed: Decimal
        let flex: Decimal
        let expected: Decimal
        let label: String

        var testDescription: String { label }
    }

    static let savingsCases: [SavingsCase] = [
        SavingsCase(income: 5000, fixed: 1500, flex: 800, expected: 2700, label: "positive savings"),
        SavingsCase(income: 2000, fixed: 1200, flex: 800, expected: 0, label: "zero savings"),
        SavingsCase(income: 2000, fixed: 1500, flex: 800, expected: -300, label: "negative savings"),
    ]

    @Test("projectedSavings computes correctly", arguments: savingsCases)
    func projectedSavings(testCase: SavingsCase) {
        let (vm, _) = makeVM()
        vm.confirmedIncomeTotal = testCase.income
        vm.confirmedFixedTotal = testCase.fixed
        vm.confirmedFlexTarget = testCase.flex

        #expect(vm.projectedSavings == testCase.expected)
    }

    // MARK: - createBudgetFromConfirmedValues

    @Test("createBudgetFromConfirmedValues passes correct values to mock including stream ID")
    func createBudgetPassesValues() async {
        let (vm, mock) = makeVM()

        vm.dateProvider = {
            var c = DateComponents()
            c.year = 2026; c.month = 4; c.day = 10; c.hour = 12
            return Calendar.current.date(from: c)!
        }
        vm.selectedPeriodType = "monthly"
        vm.computePeriodDates()

        let streamId = UUID()
        let stream = IncomeFactory.incomeStream(id: streamId, name: "Salary", amount: 5000)
        vm.confirmedStreams.append(stream)
        vm.confirmedIncomeTotal = 5000
        vm.confirmedFixedTotal = 1500
        vm.confirmedFlexTarget = 800

        mock.createPeriodResult = .success(BudgetPeriodFactory.period())

        let result = await vm.createBudgetFromConfirmedValues(accessToken: "token")

        #expect(result == true)
        #expect(mock.createPeriodCalls.count == 1)

        let call = mock.createPeriodCalls[0]
        #expect(call.startDate == "2026-04-01")
        #expect(call.endDate == "2026-05-01")
        #expect(call.incomeTarget == 5000)
        #expect(call.fixedTarget == 1500)
        #expect(call.flexTarget == 800)
        #expect(call.savingsTarget == 2700)
        #expect(call.incomeStreamId == streamId.uuidString)
    }

    @Test("createBudgetFromConfirmedValues with nil dates returns false")
    func createBudgetNilDates() async {
        let (vm, mock) = makeVM()
        // No period dates set

        let result = await vm.createBudgetFromConfirmedValues(accessToken: "token")

        #expect(result == false)
        #expect(mock.createPeriodCalls.isEmpty)
    }

    // MARK: - Emergency Fund

    @Test("createEmergencyFund happy path returns true")
    func emergencyFundSuccess() async {
        let (vm, mock) = makeVM()
        mock.createSavingsGoalResult = .success(BudgetPeriodFactory.savingsGoal())

        let result = await vm.createEmergencyFund(targetAmount: 10000, accessToken: "token")

        #expect(result == true)
        #expect(mock.createSavingsGoalCalls.count == 1)
        let call = mock.createSavingsGoalCalls[0]
        #expect(call.name == "Emergency Fund")
        #expect(call.targetAmount == 10000)
        #expect(call.isEmergencyFund == true)
        #expect(call.priority == 0)
    }

    @Test("createEmergencyFund error returns false and sets errorMessage")
    func emergencyFundError() async {
        let (vm, mock) = makeVM()
        mock.createSavingsGoalResult = .failure(NSError(domain: "test", code: 500))

        let result = await vm.createEmergencyFund(targetAmount: 10000, accessToken: "token")

        #expect(result == false)
        #expect(vm.errorMessage != nil)
    }
}
