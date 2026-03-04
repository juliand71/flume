import SwiftUI

struct PlaidLinkButton: View {
    let authService: AuthService

    @State private var isLinking = false
    @State private var errorMessage: String?
    #if os(iOS)
    @State private var linkToken: String?
    #endif

    var body: some View {
        Button {
            Task { await startLink() }
        } label: {
            if isLinking {
                ProgressView()
            } else {
                Label("Link Account", systemImage: "plus")
            }
        }
        .disabled(isLinking)
        #if os(iOS)
        .sheet(item: $linkToken) { token in
            PlaidLinkFlow(linkToken: token) { result in
                linkToken = nil
                Task { await handleLinkResult(result) }
            }
        }
        #endif
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func startLink() async {
        guard let accessToken = authService.accessToken else { return }
        isLinking = true
        do {
            let token = try await APIService.shared.createLinkToken(accessToken: accessToken)
            #if os(iOS)
            linkToken = token
            #else
            errorMessage = "Plaid Link is only available on iOS."
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
        isLinking = false
    }

    #if os(iOS)
    private func handleLinkResult(_ result: PlaidLinkResult) async {
        guard let accessToken = authService.accessToken else { return }
        switch result {
        case .success(let publicToken, let institutionName, let institutionId):
            do {
                try await APIService.shared.exchangePublicToken(
                    publicToken,
                    institutionName: institutionName,
                    institutionId: institutionId,
                    accessToken: accessToken
                )
                NotificationCenter.default.post(name: .accountsDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .cancelled:
            break
        case .failure(let message):
            errorMessage = message
        }
    }
    #endif
}

// Make String conform to Identifiable for sheet presentation
extension String: @retroactive Identifiable {
    public var id: String { self }
}
