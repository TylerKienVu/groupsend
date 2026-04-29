import SwiftUI

enum AuthState {
    case unauthenticated
    case needsProfile
    case authenticated
}

@MainActor
final class AuthManager: ObservableObject {
    @Published var state: AuthState = .unauthenticated
    @Published var currentUser: UserProfile?

    // The session token returned by POST /auth/verify — sent as Bearer on every API call
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

    func signOut() {
        sessionToken = nil
        currentUser = nil
        state = .unauthenticated
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
