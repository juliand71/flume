import Foundation

struct APIService: Sendable {
    static let shared = APIService()

    private let baseURL: URL

    private init() {
        guard let urlString = Bundle.main.infoDictionary?["RAILWAY_SERVICE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("Missing RAILWAY_SERVICE_URL in Info.plist")
        }
        baseURL = url
    }

    func createLinkToken(accessToken: String) async throws -> String {
        struct Response: Decodable {
            let link_token: String
        }
        let response: Response = try await post(path: "/link/token", body: EmptyBody(), accessToken: accessToken)
        return response.link_token
    }

    func exchangePublicToken(_ publicToken: String, institutionName: String, institutionId: String, accessToken: String) async throws {
        struct Body: Encodable {
            let public_token: String
            let institution: Institution
        }
        struct Institution: Encodable {
            let name: String
            let institution_id: String
        }
        let body = Body(
            public_token: publicToken,
            institution: Institution(name: institutionName, institution_id: institutionId)
        )
        let _: SuccessResponse = try await post(path: "/exchange", body: body, accessToken: accessToken)
    }

    func syncTransactions(plaidItemId: String, accessToken: String) async throws {
        struct Body: Encodable {
            let plaid_item_id: String
        }
        let _: SuccessResponse = try await post(path: "/sync", body: Body(plaid_item_id: plaidItemId), accessToken: accessToken)
    }

    // MARK: - Private

    private struct EmptyBody: Encodable {}
    private struct SuccessResponse: Decodable { let success: Bool }

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

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct ErrorResponse: Decodable { let error: String }
}

enum APIError: LocalizedError {
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let message): return message
        }
    }
}
