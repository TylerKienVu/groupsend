import Foundation

enum Config {
    // Publishable key is stored in Info.plist as "ClerkPublishableKey" (set in project.yml).
    // The publishable key is safe to commit — it's designed to be public.
    static let clerkPublishableKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String,
              !key.isEmpty, key != "pk_test_REPLACE_WITH_YOUR_KEY" else {
            fatalError("ClerkPublishableKey is missing or not set. Update project.yml and re-run xcodegen.")
        }
        return key
    }()

    // Your Railway API base URL. Update this after deploying.
    static let apiBaseURL = "https://groupsend-production.up.railway.app"
}
