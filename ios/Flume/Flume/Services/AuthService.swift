import Foundation
import Supabase
import Auth

@Observable
final class AuthService {
    private let client = SupabaseService.shared

    var isAuthenticated = false
    var accessToken: String?

    func initialize() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed:
                isAuthenticated = session != nil
                accessToken = session?.accessToken
            case .signedOut:
                isAuthenticated = false
                accessToken = nil
            default:
                break
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
