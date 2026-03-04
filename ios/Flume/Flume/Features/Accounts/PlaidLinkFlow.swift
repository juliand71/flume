#if os(iOS)
import SwiftUI
import LinkKit

enum PlaidLinkResult {
    case success(publicToken: String, institutionName: String, institutionId: String)
    case cancelled
    case failure(String)
}

struct PlaidLinkFlow: UIViewControllerRepresentable {
    let linkToken: String
    let onResult: (PlaidLinkResult) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()

        let linkConfiguration = LinkTokenConfiguration(token: linkToken) { result in
            switch result {
            case .success(let success):
                let publicToken = success.publicToken
                let institutionName = success.metadata.institution.name
                let institutionId = success.metadata.institution.id
                onResult(.success(
                    publicToken: publicToken,
                    institutionName: institutionName,
                    institutionId: institutionId
                ))
            case .failure(let error):
                onResult(.failure(error.localizedDescription))
            }
        }
        linkConfiguration.onExit = { exit in
            if exit.error != nil {
                onResult(.failure(exit.error?.localizedDescription ?? "Unknown error"))
            } else {
                onResult(.cancelled)
            }
        }

        let result = Plaid.create(linkConfiguration)
        switch result {
        case .success(let handler):
            // Present Plaid Link after the view controller is displayed
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(vc))
            }
        case .failure(let error):
            onResult(.failure(error.localizedDescription))
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
