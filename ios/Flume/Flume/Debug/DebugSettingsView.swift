#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @State private var store = DebugUserStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Active Debug User") {
                    ForEach(DebugUserStore.users) { user in
                        Button(action: { store.activeUserID = user.id }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.label).bold()
                                    Text(user.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.activeUserID == user.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Section("Debug Tools") {
                    NavigationLink("Create Test Transaction") {
                        DebugTransactionView()
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
