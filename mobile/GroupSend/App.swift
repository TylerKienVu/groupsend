import SwiftUI

@main
struct GroupSendApp: App {
    @StateObject private var authManager = AuthManager()
    // Invite code extracted from a groupsend://invite/:code deep link
    @State private var pendingInviteCode: String?

    var body: some Scene {
        WindowGroup {
            ContentView(pendingInviteCode: $pendingInviteCode)
                .environmentObject(authManager)
                .preferredColorScheme(.dark) // design is dark-only
                .onOpenURL { url in
                    // Handle groupsend://invite/:code
                    if url.scheme == "groupsend",
                       url.host == "invite",
                       let code = url.pathComponents.dropFirst().first {
                        pendingInviteCode = code
                    }
                }
        }
    }
}
