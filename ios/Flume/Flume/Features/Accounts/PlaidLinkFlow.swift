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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> PlaidLinkViewController {
        let vc = PlaidLinkViewController()

        var linkConfiguration = LinkTokenConfiguration(token: linkToken) { success in
            let publicToken = success.publicToken
            let institutionName = success.metadata.institution.name
            let institutionId = success.metadata.institution.id
            onResult(.success(
                publicToken: publicToken,
                institutionName: institutionName,
                institutionId: institutionId
            ))
        }
        linkConfiguration.onExit = { (exit: LinkExit) in
            if let error = exit.error {
                onResult(.failure(error.errorMessage))
            } else {
                onResult(.cancelled)
            }
        }

        let result = Plaid.create(linkConfiguration)
        switch result {
        case .success(let handler):
            context.coordinator.handler = handler
            vc.onViewDidAppear = {
                handler.open(presentUsing: .viewController(vc))
            }
        case .failure(let error):
            onResult(.failure(error.localizedDescription))
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: PlaidLinkViewController, context: Context) {}

    class Coordinator {
        // Hold a strong reference so the handler isn't deallocated
        var handler: Handler?
    }
}

/// A UIViewController that notifies when it has appeared in the hierarchy.
final class PlaidLinkViewController: UIViewController {
    var onViewDidAppear: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onViewDidAppear?()
        onViewDidAppear = nil // Only fire once
    }
}
#endif
