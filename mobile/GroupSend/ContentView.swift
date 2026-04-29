import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var pendingInviteCode: String?
    @Binding var pendingCheckinGroupId: String?

    var body: some View {
        Group {
            switch authManager.state {
            case .unauthenticated:
                PhoneEntryView()
            case .needsProfile:
                ProfileCreationView()
            case .authenticated:
                GroupListView(pendingCheckinGroupId: $pendingCheckinGroupId)
            }
        }
        .sheet(item: Binding(
            get: { pendingInviteCode.map { InviteCode(value: $0) } },
            set: { pendingInviteCode = $0?.value }
        )) { code in
            InviteView(inviteCode: code.value)
                .environmentObject(authManager)
        }
    }
}

private struct InviteCode: Identifiable {
    let value: String
    var id: String { value }
}
