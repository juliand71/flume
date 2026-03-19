import Foundation

struct BudgetAPIService: Sendable {
    static let shared = BudgetAPIService()

    private let baseURL: URL

    private init() {
        guard let urlString = Bundle.main.infoDictionary?["BUDGET_API_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("Missing BUDGET_API_URL in Info.plist")
        }
        baseURL = url
    }

    func fetchAccounts(accessToken: String) async throws -> [Account] {
        struct Response: Decodable {
            let accounts: [Account]
        }
        let response: Response = try await get(path: "/budget/accounts", accessToken: accessToken)
        return response.accounts
    }

    func updateAccountRole(id: String, role: String, accessToken: String) async throws -> Account {
        struct Body: Encodable {
            let account_role: String
        }
        return try await patch(path: "/budget/accounts/\(id)/role", body: Body(account_role: role), accessToken: accessToken)
    }

    // MARK: - Income Streams

    func fetchIncomeStreams(accessToken: String) async throws -> [IncomeStream] {
        struct Response: Decodable {
            let incomeStreams: [IncomeStream]
        }
        let response: Response = try await get(path: "/budget/income-streams", accessToken: accessToken)
        return response.incomeStreams
    }

    func createIncomeStream(name: String, estimatedAmount: Decimal, frequency: String, nextExpectedDate: String?, accessToken: String) async throws -> IncomeStream {
        struct Body: Encodable {
            let name: String
            let estimated_amount: Decimal
            let frequency: String
            let next_expected_date: String?
        }
        return try await post(path: "/budget/income-streams", body: Body(name: name, estimated_amount: estimatedAmount, frequency: frequency, next_expected_date: nextExpectedDate), accessToken: accessToken)
    }

    func updateIncomeStream(id: String, name: String?, estimatedAmount: Decimal?, frequency: String?, accessToken: String) async throws -> IncomeStream {
        struct Body: Encodable {
            let name: String?
            let estimated_amount: Decimal?
            let frequency: String?
        }
        return try await patch(path: "/budget/income-streams/\(id)", body: Body(name: name, estimated_amount: estimatedAmount, frequency: frequency), accessToken: accessToken)
    }

    func deleteIncomeStream(id: String, accessToken: String) async throws {
        try await delete(path: "/budget/income-streams/\(id)", accessToken: accessToken)
    }

    // MARK: - Budget Periods

    func fetchCurrentPeriod(accessToken: String) async throws -> BudgetPeriod {
        return try await get(path: "/budget/current-period", accessToken: accessToken)
    }

    func fetchPeriods(limit: Int = 20, offset: Int = 0, accessToken: String) async throws -> (periods: [BudgetPeriod], total: Int) {
        struct Response: Decodable {
            let periods: [BudgetPeriod]
            let total: Int
        }
        let response: Response = try await get(path: "/budget/periods?limit=\(limit)&offset=\(offset)", accessToken: accessToken)
        return (response.periods, response.total)
    }

    func createPeriod(startDate: String, endDate: String, incomeTarget: Decimal, fixedTarget: Decimal, flexTarget: Decimal, savingsTarget: Decimal, incomeStreamId: String?, accessToken: String) async throws -> BudgetPeriod {
        struct Body: Encodable {
            let start_date: String
            let end_date: String
            let income_target: Decimal
            let fixed_target: Decimal
            let flex_target: Decimal
            let savings_target: Decimal
            let income_stream_id: String?
        }
        return try await post(path: "/budget/periods", body: Body(start_date: startDate, end_date: endDate, income_target: incomeTarget, fixed_target: fixedTarget, flex_target: flexTarget, savings_target: savingsTarget, income_stream_id: incomeStreamId), accessToken: accessToken)
    }

    func updatePeriod(id: String, incomeTarget: Decimal?, fixedTarget: Decimal?, flexTarget: Decimal?, savingsTarget: Decimal?, accessToken: String) async throws -> BudgetPeriod {
        struct Body: Encodable {
            let income_target: Decimal?
            let fixed_target: Decimal?
            let flex_target: Decimal?
            let savings_target: Decimal?
        }
        return try await patch(path: "/budget/periods/\(id)", body: Body(income_target: incomeTarget, fixed_target: fixedTarget, flex_target: flexTarget, savings_target: savingsTarget), accessToken: accessToken)
    }

    // MARK: - Category Summary

    func fetchCategorySummary(accessToken: String) async throws -> CategorySummaryResponse {
        return try await get(path: "/budget/category-summary", accessToken: accessToken)
    }

    // MARK: - Transactions

    func fetchTransactions(periodId: String, category: String? = nil, accessToken: String) async throws -> [BudgetTransaction] {
        struct Response: Decodable {
            let transactions: [BudgetTransaction]
        }
        var path = "/budget/transactions?period_id=\(periodId)"
        if let category {
            path += "&category=\(category)"
        }
        let response: Response = try await get(path: path, accessToken: accessToken)
        return response.transactions
    }

    func overrideTransactionCategory(id: String, budgetCategory: String, accessToken: String) async throws -> BudgetTransaction {
        struct Body: Encodable {
            let budget_category: String
        }
        return try await post(path: "/budget/transactions/\(id)/override", body: Body(budget_category: budgetCategory), accessToken: accessToken)
    }

    // MARK: - Category Mappings

    func fetchCategoryMappings(accessToken: String) async throws -> [CategoryMapping] {
        struct Response: Decodable {
            let categoryMappings: [CategoryMapping]
        }
        let response: Response = try await get(path: "/budget/categories", accessToken: accessToken)
        return response.categoryMappings
    }

    func createCategoryMapping(plaidPrimaryCategory: String, plaidDetailedCategory: String?, budgetCategory: String, accessToken: String) async throws -> CategoryMapping {
        struct Body: Encodable {
            let plaid_primary_category: String
            let plaid_detailed_category: String?
            let budget_category: String
        }
        return try await post(path: "/budget/categories", body: Body(plaid_primary_category: plaidPrimaryCategory, plaid_detailed_category: plaidDetailedCategory, budget_category: budgetCategory), accessToken: accessToken)
    }

    // MARK: - Savings Goals

    func fetchSavingsGoals(accessToken: String) async throws -> [SavingsGoal] {
        struct Response: Decodable {
            let savingsGoals: [SavingsGoal]
        }
        let response: Response = try await get(path: "/budget/savings-goals", accessToken: accessToken)
        return response.savingsGoals
    }

    func createSavingsGoal(name: String, targetAmount: Decimal, emoji: String?, isEmergencyFund: Bool, priority: Int, accessToken: String) async throws -> SavingsGoal {
        struct Body: Encodable {
            let name: String
            let target_amount: Decimal
            let emoji: String?
            let is_emergency_fund: Bool
            let priority: Int
        }
        return try await post(path: "/budget/savings-goals", body: Body(name: name, target_amount: targetAmount, emoji: emoji, is_emergency_fund: isEmergencyFund, priority: priority), accessToken: accessToken)
    }

    func updateSavingsGoal(id: String, name: String?, targetAmount: Decimal?, emoji: String?, isEmergencyFund: Bool?, priority: Int?, accessToken: String) async throws -> SavingsGoal {
        struct Body: Encodable {
            let name: String?
            let target_amount: Decimal?
            let emoji: String?
            let is_emergency_fund: Bool?
            let priority: Int?
        }
        return try await patch(path: "/budget/savings-goals/\(id)", body: Body(name: name, target_amount: targetAmount, emoji: emoji, is_emergency_fund: isEmergencyFund, priority: priority), accessToken: accessToken)
    }

    func deleteSavingsGoal(id: String, accessToken: String) async throws {
        try await delete(path: "/budget/savings-goals/\(id)", accessToken: accessToken)
    }

    func fillSavingsGoals(allocations: [(savingsGoalId: String, amount: Decimal)], accessToken: String) async throws -> [SavingsGoal] {
        struct Allocation: Encodable {
            let savings_goal_id: String
            let amount: Decimal
        }
        struct Body: Encodable {
            let allocations: [Allocation]
        }
        struct Response: Decodable {
            let savingsGoals: [SavingsGoal]
        }
        let body = Body(allocations: allocations.map { Allocation(savings_goal_id: $0.savingsGoalId, amount: $0.amount) })
        let response: Response = try await post(path: "/budget/savings-goals/fill", body: body, accessToken: accessToken)
        return response.savingsGoals
    }

    // MARK: - Private

    private func get<Response: Decodable>(path: String, accessToken: String) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let status = (httpResponse as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(errorBody?.error ?? "Unknown error")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    private func patch<Body: Encodable, Response: Decodable>(path: String, body: Body, accessToken: String) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let status = (httpResponse as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(errorBody?.error ?? "Unknown error")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    private func post<Body: Encodable, Response: Decodable>(path: String, body: Body, accessToken: String) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let status = (httpResponse as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(errorBody?.error ?? "Unknown error")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    private func delete(path: String, accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let status = (httpResponse as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(errorBody?.error ?? "Unknown error")
        }
    }

    private struct ErrorResponse: Decodable { let error: String }
}
