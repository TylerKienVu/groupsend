import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var pendingInviteCode: String?

    var body: some View {
        Group {
            switch authManager.state {
            case .unauthenticated:
                PhoneEntryView()
            case .needsProfile:
                ProfileCreationView()
            case .authenticated:
                GroupListView()
            }
        }
        // Show the invite sheet whenever a deep link arrives, regardless of auth state
        .sheet(item: Binding(
            get: { pendingInviteCode.map { InviteCode(value: $0) } },
            set: { pendingInviteCode = $0?.value }
        )) { code in
            InviteView(inviteCode: code.value)
                .environmentObject(authManager)
        }
    }
}

// Thin Identifiable wrapper so the invite code can drive a .sheet(item:)
private struct InviteCode: Identifiable {
    let value: String
    var id: String { value }
}
