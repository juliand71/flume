#if DEBUG
import Foundation

@Observable
final class DebugUserStore {
    static let shared = DebugUserStore()
    private let key = "debugUserID"

    static let onboardedID = "00000000-0000-0000-0000-000000000000"
    static let freshID     = "00000000-0000-0000-0000-000000000001"

    var activeUserID: String {
        get { UserDefaults.standard.string(forKey: key) ?? DebugUserStore.onboardedID }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var isFreshUser: Bool {
        activeUserID == DebugUserStore.freshID
    }
}
#endif
