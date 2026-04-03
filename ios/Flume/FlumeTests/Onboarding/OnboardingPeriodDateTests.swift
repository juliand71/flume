import Testing
import Foundation
@testable import Flume

@Suite("Onboarding Period Date Computation")
struct OnboardingPeriodDateTests {

    /// April 10, 2026 pinned date
    private static let pinnedDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 10
        components.hour = 12
        return Calendar.current.date(from: components)!
    }()

    private func makeVM() -> (OnboardingViewModel, MockBudgetAPIService) {
        let mock = MockBudgetAPIService()
        let vm = OnboardingViewModel(budgetAPI: mock)
        vm.dateProvider = { OnboardingPeriodDateTests.pinnedDate }
        return (vm, mock)
    }

    private func dateComponents(_ date: Date?) -> DateComponents? {
        guard let date else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }

    // MARK: - Monthly

    @Test("Monthly period starts on the 1st and ends on the 1st of next month")
    func monthlyPeriodDates() {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "monthly"
        vm.computePeriodDates()

        let start = dateComponents(vm.periodStartDate)
        let end = dateComponents(vm.periodEndDate)

        #expect(start?.year == 2026)
        #expect(start?.month == 4)
        #expect(start?.day == 1)
        #expect(end?.year == 2026)
        #expect(end?.month == 5)
        #expect(end?.day == 1)
    }

    // MARK: - Semimonthly

    @Test("Semimonthly half 1 runs from 1st to 16th")
    func semimonthlyHalf1() {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "semimonthly"
        vm.semimonthlyHalf = 1
        vm.computePeriodDates()

        let start = dateComponents(vm.periodStartDate)
        let end = dateComponents(vm.periodEndDate)

        #expect(start?.day == 1)
        #expect(start?.month == 4)
        #expect(end?.day == 16)
        #expect(end?.month == 4)
    }

    @Test("Semimonthly half 2 runs from 16th to 1st of next month")
    func semimonthlyHalf2() {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "semimonthly"
        vm.semimonthlyHalf = 2
        vm.computePeriodDates()

        let start = dateComponents(vm.periodStartDate)
        let end = dateComponents(vm.periodEndDate)

        #expect(start?.day == 16)
        #expect(start?.month == 4)
        #expect(end?.day == 1)
        #expect(end?.month == 5)
    }

    // MARK: - Biweekly

    @Test("Biweekly with anchor in the past aligns to a 14-day period containing today")
    func biweeklyAnchorPast() {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "biweekly"

        // Anchor: March 13, 2026 (28 days before April 10)
        var anchorComps = DateComponents()
        anchorComps.year = 2026
        anchorComps.month = 3
        anchorComps.day = 13
        vm.biweeklyAnchorDate = Calendar.current.date(from: anchorComps)

        vm.computePeriodDates()

        let start = dateComponents(vm.periodStartDate)
        let end = dateComponents(vm.periodEndDate)

        // March 13 + 14 = March 27, + 14 = April 10
        #expect(start?.month == 4)
        #expect(start?.day == 10)
        #expect(end?.month == 4)
        #expect(end?.day == 24)
    }

    @Test("Biweekly with anchor in the future walks back to find period containing today")
    func biweeklyAnchorFuture() {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "biweekly"

        // Anchor: April 20, 2026 (10 days after today)
        var anchorComps = DateComponents()
        anchorComps.year = 2026
        anchorComps.month = 4
        anchorComps.day = 20
        vm.biweeklyAnchorDate = Calendar.current.date(from: anchorComps)

        vm.computePeriodDates()

        let start = dateComponents(vm.periodStartDate)
        let end = dateComponents(vm.periodEndDate)

        // April 20 > April 10 (today), so walk back: April 20 - 14 = April 6
        #expect(start?.month == 4)
        #expect(start?.day == 6)
        #expect(end?.month == 4)
        #expect(end?.day == 20)
    }

    @Test("Biweekly with nil anchor leaves dates nil")
    func biweeklyNilAnchor() {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "biweekly"
        vm.biweeklyAnchorDate = nil
        vm.computePeriodDates()

        #expect(vm.periodStartDate == nil)
        #expect(vm.periodEndDate == nil)
    }

    // MARK: - Weekly

    @Test("Weekly computes correct start for each weekday", arguments: 1...7)
    func weeklyStartDay(day: Int) {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "weekly"
        vm.weeklyStartDay = day
        vm.computePeriodDates()

        #expect(vm.periodStartDate != nil)
        #expect(vm.periodEndDate != nil)

        let calendar = Calendar.current
        let startWeekday = calendar.component(.weekday, from: vm.periodStartDate!)
        #expect(startWeekday == day)

        let daysBetween = calendar.dateComponents([.day], from: vm.periodStartDate!, to: vm.periodEndDate!).day
        #expect(daysBetween == 7)
    }

    // MARK: - Unknown

    @Test("Unknown period type leaves dates nil")
    func unknownPeriodType() {
        let (vm, _) = makeVM()
        vm.selectedPeriodType = "quarterly"
        vm.computePeriodDates()

        #expect(vm.periodStartDate == nil)
        #expect(vm.periodEndDate == nil)
    }
}
