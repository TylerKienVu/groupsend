import SwiftUI
import ClerkKit

enum AuthState {
    case unauthenticated
    case needsProfile
    case authenticated
}

@MainActor
final class AuthManager: ObservableObject {
    @Published var state: AuthState = .unauthenticated
    @Published var currentUser: UserProfile?

    // The Clerk JWT — sent as Authorization: Bearer on every API call
    var sessionToken: String?

    func signIn(token: String, hasProfile: Bool) {
        sessionToken = token
        state = hasProfile ? .authenticated : .needsProfile
    }

    func profileCreated(user: UserProfile) {
        currentUser = user
        state = .authenticated
    }

    func userLoaded(_ user: UserProfile) {
        currentUser = user
    }

    // Called at app launch after Clerk.configure(). If Clerk restored a saved session,
    // we grab its JWT and check whether this user already has a profile in our DB.
    func restoreSessionIfNeeded() async {
        guard let session = Clerk.shared.session,
              let token = try? await session.getToken() else {
            return  // no saved session — stay unauthenticated
        }
        sessionToken = token
        let profile = try? await APIClient(token: token).getMe()
        if let profile {
            currentUser = profile
            state = .authenticated
        } else {
            // No backend profile means the user never finished onboarding or the
            // session is from an abandoned attempt. Sign out and restart the flow.
            sessionToken = nil
            Task { try? await Clerk.shared.auth.signOut() }
        }
    }

    func signOut() {
        sessionToken = nil
        currentUser = nil
        state = .unauthenticated
        Task { try? await Clerk.shared.auth.signOut() }
    }

    func apiClient() -> APIClient {
        APIClient(token: sessionToken)
    }

    func registerDeviceToken(_ token: String) async {
        guard sessionToken != nil else { return }
        try? await apiClient().putDeviceToken(token)
    }

    func clearDeviceToken() async {
        try? await apiClient().putDeviceToken(nil)
    }
}
