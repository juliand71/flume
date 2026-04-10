#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @State private var store = DebugUserStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Active Debug User") {
                    Button(action: { store.activeUserID = DebugUserStore.onboardedID }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Onboarded (default)").bold()
                                Text("Full data, onboarding complete").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !store.isFreshUser { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { store.activeUserID = DebugUserStore.freshID }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Fresh (no data)").bold()
                                Text("No bank linked, starts at onboarding").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.isFreshUser { Image(systemName: "checkmark") }
                        }
                    }
                }
                Section {
                    Text("Changes take effect on next sign-out/sign-in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Debug Settings")
        }
    }
}
#endif
