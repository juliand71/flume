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

    private struct ErrorResponse: Decodable { let error: String }
}
