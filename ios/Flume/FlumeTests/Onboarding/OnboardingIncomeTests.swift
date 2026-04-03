import Testing
import Foundation
@testable import Flume

@Suite("Onboarding Income Detection")
struct OnboardingIncomeTests {

    private func makeVM() -> (OnboardingViewModel, MockBudgetAPIService) {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        return (vm, mock)
    }

    // MARK: - detectIncome

    @Test("detectIncome populates detectedStreams, monthlyExpenseEstimate, and dateRangeDays")
    func detectIncomePopulatesFields() async {
        let (vm, mock) = makeVM()
        let streams = [IncomeFactory.monthly()]
        mock.detectIncomeResult = .success(
            IncomeFactory.detectionResponse(streams: streams, monthlyExpense: 4200, dateRangeDays: 120)
        )

        await vm.detectIncome(accessToken: "token")

        #expect(vm.detectedStreams.count == 1)
        #expect(vm.detectedStreams.first?.name == "Monthly Salary")
        #expect(vm.monthlyExpenseEstimate == 4200)
        #expect(vm.dateRangeDays == 120)
    }

    @Test("detectIncome with expandedSearch nil defaults to false")
    func expandedSearchNilDefaultsFalse() async {
        let (vm, mock) = makeVM()
        mock.detectIncomeResult = .success(
            IncomeFactory.detectionResponse(expandedSearch: nil)
        )

        await vm.detectIncome(accessToken: "token")

        #expect(vm.expandedSearch == false)
    }

    @Test("isLoading becomes false after detectIncome completes")
    func isLoadingLifecycle() async {
        let (vm, mock) = makeVM()
        mock.detectIncomeResult = .success(IncomeFactory.detectionResponse())

        await vm.detectIncome(accessToken: "token")

        #expect(vm.isLoading == false)
    }

    @Test("detectIncome API error sets errorMessage")
    func detectIncomeError() async {
        let (vm, mock) = makeVM()
        mock.detectIncomeResult = .failure(NSError(domain: "test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"]))

        await vm.detectIncome(accessToken: "token")

        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage?.contains("detect income") == true)
        #expect(vm.detectedStreams.isEmpty)
    }

    @Test("Each frequency type is preserved", arguments: ["weekly", "biweekly", "semimonthly", "monthly"])
    func frequencyPreserved(frequency: String) async {
        let (vm, mock) = makeVM()
        let stream = IncomeFactory.detectedStream(frequency: frequency)
        mock.detectIncomeResult = .success(
            IncomeFactory.detectionResponse(streams: [stream])
        )

        await vm.detectIncome(accessToken: "token")

        #expect(vm.detectedStreams.first?.frequency == frequency)
    }

    @Test("No streams returns empty array")
    func noStreams() async {
        let (vm, mock) = makeVM()
        mock.detectIncomeResult = .success(
            IncomeFactory.detectionResponse(streams: [])
        )

        await vm.detectIncome(accessToken: "token")

        #expect(vm.detectedStreams.isEmpty)
    }

    @Test("Multiple streams all populated")
    func multipleStreams() async {
        let (vm, mock) = makeVM()
        let streams = IncomeFactory.multipleStreams()
        mock.detectIncomeResult = .success(
            IncomeFactory.detectionResponse(streams: streams)
        )

        await vm.detectIncome(accessToken: "token")

        #expect(vm.detectedStreams.count == 2)
    }

    // MARK: - confirmIncomeStream

    @Test("confirmIncomeStream success appends to confirmedStreams")
    func confirmIncomeStreamSuccess() async {
        let (vm, mock) = makeVM()
        let returned = IncomeFactory.incomeStream(name: "Paycheck", amount: 3000)
        mock.createIncomeStreamResult = .success(returned)

        let result = await vm.confirmIncomeStream(
            name: "Paycheck",
            estimatedAmount: 3000,
            frequency: "biweekly",
            nextExpectedDate: "2026-04-15",
            accessToken: "token"
        )

        #expect(result != nil)
        #expect(result?.name == "Paycheck")
        #expect(vm.confirmedStreams.count == 1)
        #expect(vm.confirmedStreams.first?.name == "Paycheck")
    }

    @Test("confirmIncomeStream error returns nil")
    func confirmIncomeStreamError() async {
        let (vm, mock) = makeVM()
        mock.createIncomeStreamResult = .failure(NSError(domain: "test", code: 400))

        let result = await vm.confirmIncomeStream(
            name: "Paycheck",
            estimatedAmount: 3000,
            frequency: "biweekly",
            nextExpectedDate: nil,
            accessToken: "token"
        )

        #expect(result == nil)
        #expect(vm.confirmedStreams.isEmpty)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Parameter verification

    @Test("detectIncome passes period dates to the API")
    func detectIncomePassesDates() async {
        let (vm, mock) = makeVM()
        mock.detectIncomeResult = .success(IncomeFactory.detectionResponse())

        // Set up period dates
        vm.selectedPeriodType = "monthly"
        vm.dateProvider = {
            var c = DateComponents()
            c.year = 2026; c.month = 4; c.day = 10; c.hour = 12
            return Calendar.current.date(from: c)!
        }
        vm.computePeriodDates()

        await vm.detectIncome(accessToken: "test-token")

        #expect(mock.detectIncomeCalls.count == 1)
        let call = mock.detectIncomeCalls[0]
        #expect(call.startDate == "2026-04-01")
        #expect(call.endDate == "2026-05-01")
        #expect(call.accessToken == "test-token")
    }

    @Test("confirmIncomeStream passes correct parameters to mock")
    func confirmIncomeStreamParams() async {
        let (vm, mock) = makeVM()
        mock.createIncomeStreamResult = .success(IncomeFactory.incomeStream())

        _ = await vm.confirmIncomeStream(
            name: "Side Gig",
            estimatedAmount: 1500,
            frequency: "weekly",
            nextExpectedDate: "2026-04-17",
            accessToken: "abc123"
        )

        #expect(mock.createIncomeStreamCalls.count == 1)
        let call = mock.createIncomeStreamCalls[0]
        #expect(call.name == "Side Gig")
        #expect(call.estimatedAmount == 1500)
        #expect(call.frequency == "weekly")
        #expect(call.nextExpectedDate == "2026-04-17")
        #expect(call.accessToken == "abc123")
    }
}
