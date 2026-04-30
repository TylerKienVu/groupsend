import SwiftUI
import UserNotifications
import ClerkKit

// AppDelegate handles the APNs token callback, which SwiftUI's App lifecycle
// doesn't expose directly. @UIApplicationDelegateAdaptor bridges the two.
class AppDelegate: NSObject, UIApplicationDelegate {
    var onDeviceToken: ((String) -> Void)?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert the raw bytes to a hex string — that's the format APNs expects
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        onDeviceToken?(tokenString)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Failed to register: \(error)")
    }
}

@main
struct GroupSendApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authManager = AuthManager()
    @State private var pendingInviteCode: String?
    @State private var pendingCheckinGroupId: String?

    var body: some Scene {
        WindowGroup {
            ContentView(
                pendingInviteCode: $pendingInviteCode,
                pendingCheckinGroupId: $pendingCheckinGroupId
            )
            .environmentObject(authManager)
            .preferredColorScheme(.dark)
            .task { await loadClerk() }
            .onOpenURL { url in
                guard url.scheme == "groupsend" else { return }
                if url.host == "invite",
                   let code = url.pathComponents.dropFirst().first {
                    pendingInviteCode = code
                } else if url.host == "checkin",
                          let groupId = url.pathComponents.dropFirst().first {
                    pendingCheckinGroupId = groupId
                }
            }
            .onAppear {
                appDelegate.onDeviceToken = { token in
                    Task { await authManager.registerDeviceToken(token) }
                }
                requestNotificationPermission()
            }
        }
    }

    private func loadClerk() async {
        // configure() is synchronous: loads cached session from keychain, starts
        // background token refresh. restoreSessionIfNeeded() reads Clerk.shared.session
        // immediately after — the cache is populated synchronously by configure().
        Clerk.configure(publishableKey: Config.clerkPublishableKey)
        await authManager.restoreSessionIfNeeded()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
