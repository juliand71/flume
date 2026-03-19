import Foundation
import Supabase

@Observable
final class SavingsGoalViewModel {
    var goals: [SavingsGoal] = []
    var isLoading = false
    var errorMessage: String?

    private let client = SupabaseService.shared

    func fetchGoals() async {
        isLoading = true
        errorMessage = nil
        do {
            let accessToken = try await client.auth.session.accessToken
            goals = try await BudgetAPIService.shared.fetchSavingsGoals(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createGoal(name: String, targetAmount: Decimal, emoji: String?, isEmergencyFund: Bool, priority: Int) async {
        do {
            let accessToken = try await client.auth.session.accessToken
            let goal = try await BudgetAPIService.shared.createSavingsGoal(
                name: name, targetAmount: targetAmount, emoji: emoji,
                isEmergencyFund: isEmergencyFund, priority: priority,
                accessToken: accessToken
            )
            goals.append(goal)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateGoal(id: String, name: String?, targetAmount: Decimal?, emoji: String?, isEmergencyFund: Bool?, priority: Int?) async {
        do {
            let accessToken = try await client.auth.session.accessToken
            let updated = try await BudgetAPIService.shared.updateSavingsGoal(
                id: id, name: name, targetAmount: targetAmount, emoji: emoji,
                isEmergencyFund: isEmergencyFund, priority: priority,
                accessToken: accessToken
            )
            if let index = goals.firstIndex(where: { $0.id == updated.id }) {
                goals[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGoal(id: String) async {
        do {
            let accessToken = try await client.auth.session.accessToken
            try await BudgetAPIService.shared.deleteSavingsGoal(id: id, accessToken: accessToken)
            goals.removeAll { $0.id.uuidString == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fillGoals(allocations: [(savingsGoalId: String, amount: Decimal)]) async -> Bool {
        do {
            let accessToken = try await client.auth.session.accessToken
            goals = try await BudgetAPIService.shared.fillSavingsGoals(
                allocations: allocations, accessToken: accessToken
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
