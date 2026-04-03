import Testing
import Foundation
@testable import Flume

@Suite("Onboarding Combination: Period Configs x Income Frequencies")
struct OnboardingCombinationTests {

    enum PeriodConfig: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case monthly
        case semimonthlyHalf1 = "semimonthly_half1"
        case semimonthlyHalf2 = "semimonthly_half2"
        case biweekly
        case weekly

        var testDescription: String { rawValue }
    }

    struct CombinationCase: Sendable, CustomTestStringConvertible {
        let period: PeriodConfig
        let frequency: String

        var testDescription: String { "\(period.rawValue) + \(frequency)" }
    }

    static let allCombinations: [CombinationCase] = {
        let periods = PeriodConfig.allCases
        let frequencies = ["weekly", "biweekly", "semimonthly", "monthly"]
        return periods.flatMap { period in
            frequencies.map { freq in
                CombinationCase(period: period, frequency: freq)
            }
        }
    }()

    /// April 10, 2026 pinned date
    private static let pinnedDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 10
        components.hour = 12
        return Calendar.current.date(from: components)!
    }()

    private func configureVM(_ vm: OnboardingViewModel, period: PeriodConfig) {
        vm.dateProvider = { OnboardingCombinationTests.pinnedDate }

        switch period {
        case .monthly:
            vm.selectedPeriodType = "monthly"
        case .semimonthlyHalf1:
            vm.selectedPeriodType = "semimonthly"
            vm.semimonthlyHalf = 1
        case .semimonthlyHalf2:
            vm.selectedPeriodType = "semimonthly"
            vm.semimonthlyHalf = 2
        case .biweekly:
            vm.selectedPeriodType = "biweekly"
            var anchorComps = DateComponents()
            anchorComps.year = 2026
            anchorComps.month = 3
            anchorComps.day = 13
            vm.biweeklyAnchorDate = Calendar.current.date(from: anchorComps)
        case .weekly:
            vm.selectedPeriodType = "weekly"
            vm.weeklyStartDay = 2 // Monday
        }
    }

    @Test("Period config and income frequency combination", arguments: allCombinations)
    func combinationTest(testCase: CombinationCase) async {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)

        // Configure and compute period
        configureVM(vm, period: testCase.period)
        vm.computePeriodDates()

        // Verify dates were computed
        #expect(vm.periodStartDate != nil)
        #expect(vm.periodEndDate != nil)

        let expectedStart = vm.periodStartDateString
        let expectedEnd = vm.periodEndDateString

        // Set up mock for income detection with the given frequency
        let stream = IncomeFactory.detectedStream(frequency: testCase.frequency)
        mock.detectIncomeResult = .success(
            IncomeFactory.detectionResponse(streams: [stream])
        )

        // Run income detection
        await vm.detectIncome(accessToken: "token")

        // Verify the API was called with the period dates
        #expect(mock.detectIncomeCalls.count == 1)
        let call = mock.detectIncomeCalls[0]
        #expect(call.startDate == expectedStart)
        #expect(call.endDate == expectedEnd)

        // Verify the stream frequency is preserved
        #expect(vm.detectedStreams.count == 1)
        #expect(vm.detectedStreams.first?.frequency == testCase.frequency)
    }
}
