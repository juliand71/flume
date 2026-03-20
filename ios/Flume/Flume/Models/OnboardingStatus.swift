import Foundation

struct OnboardingStatus: Codable, Sendable {
    let onboardingStep: String?
    let hasPlaidItems: Bool
    let transactionCount: Int
    let hasIncomeStreams: Bool
    let hasBudgetPeriod: Bool
    let hasSavingsGoal: Bool
}

struct SyncStatus: Codable, Sendable {
    let hasPlaidItems: Bool
    let transactionCount: Int
}
