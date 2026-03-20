import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService
    @State private var onboardingStep: String?
    @State private var isCheckingOnboarding = false
    @State private var hasCheckedOnboarding = false

    var body: some View {
        Group {
            if !authService.isAuthenticated {
                LoginView(viewModel: AuthViewModel(authService: authService))
            } else if isCheckingOnboarding {
                ProgressView()
            } else if let step = onboardingStep, step != "complete" {
                OnboardingContainerView {
                    onboardingStep = nil
                }
            } else {
                MainTabView()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                Task { await checkOnboarding() }
            } else {
                onboardingStep = nil
                hasCheckedOnboarding = false
            }
        }
        .task {
            if authService.isAuthenticated && !hasCheckedOnboarding {
                await checkOnboarding()
            }
        }
    }

    private func checkOnboarding() async {
        guard let token = authService.accessToken else { return }
        isCheckingOnboarding = true
        defer {
            isCheckingOnboarding = false
            hasCheckedOnboarding = true
        }
        do {
            let status = try await BudgetAPIService.shared.fetchOnboardingStatus(accessToken: token)
            onboardingStep = status.onboardingStep
        } catch {
            // If status check fails, skip onboarding (don't block existing users)
            onboardingStep = nil
        }
    }
}
