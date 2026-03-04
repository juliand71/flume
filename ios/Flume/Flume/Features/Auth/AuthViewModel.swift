import Foundation

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
