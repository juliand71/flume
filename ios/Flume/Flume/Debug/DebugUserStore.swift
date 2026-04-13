#if DEBUG
import Foundation

struct DebugUser: Identifiable {
    let id: String
    let label: String
    let subtitle: String
}

@Observable
final class DebugUserStore {
    static let shared = DebugUserStore()
    private let key = "debugUserID"

    static let onboardedID = "00000000-0000-0000-0000-000000000000"
    static let freshID     = "00000000-0000-0000-0000-000000000001"

    static let users: [DebugUser] = [
        DebugUser(id: "00000000-0000-0000-0000-000000000000", label: "Monthly (default)", subtitle: "Biweekly income, monthly periods, full data"),
        DebugUser(id: "00000000-0000-0000-0000-000000000001", label: "Fresh (no data)", subtitle: "Not onboarded, starts at welcome"),
        DebugUser(id: "00000000-0000-0000-0000-000000000002", label: "Weekly", subtitle: "Freelancer, weekly pay & budget periods"),
        DebugUser(id: "00000000-0000-0000-0000-000000000003", label: "Biweekly", subtitle: "Salaried, biweekly pay & budget periods"),
        DebugUser(id: "00000000-0000-0000-0000-000000000004", label: "Semimonthly", subtitle: "Paid 1st & 15th, half-month periods"),
        DebugUser(id: "00000000-0000-0000-0000-000000000005", label: "Overspender", subtitle: "Monthly, over budget in multiple categories"),
    ]

    var activeUserID: String {
        get { UserDefaults.standard.string(forKey: key) ?? DebugUserStore.onboardedID }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var isFreshUser: Bool {
        activeUserID == DebugUserStore.freshID
    }
}
#endif
