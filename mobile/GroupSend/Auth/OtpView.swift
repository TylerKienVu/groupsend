import SwiftUI
import ClerkKit

struct OtpView: View {
    let phoneNumber: String
    let clerkSignIn: SignIn
    @EnvironmentObject private var authManager: AuthManager
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedIndex: Int?

    private var code: String { digits.joined() }
    private var isComplete: Bool { code.count == 6 }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                HStack {
                    // Back button (navigation pop)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DS.text)
                        .frame(width: 36, height: 36)
                        .background(DS.surface2)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.border, lineWidth: 1))
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)

                // ── Copy ─────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter the code")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(DS.text)
                        .tracking(-0.9)

                    HStack(spacing: 4) {
                        Text("Sent to")
                            .foregroundColor(DS.textDim)
                        Text(phoneNumber)
                            .foregroundColor(DS.text)
                    }
                    .font(.system(size: 15))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 12)

                // ── 6 digit boxes ─────────────────────────────────────────
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { i in
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.rMd)
                                .fill(DS.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.rMd)
                                        .stroke(
                                            focusedIndex == i ? DS.accent : DS.border,
                                            lineWidth: focusedIndex == i ? 2 : 1
                                        )
                                )
                                .shadow(
                                    color: focusedIndex == i ? DS.accent.opacity(0.2) : .clear,
                                    radius: 8
                                )

                            if digits[i].isEmpty && focusedIndex == i {
                                // Blinking cursor in the active empty cell
                                Rectangle()
                                    .fill(DS.accent)
                                    .frame(width: 2, height: 24)
                                    .opacity(0.9)
                            } else {
                                Text(digits[i])
                                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                                    .foregroundColor(DS.text)
                            }
                        }
                        .frame(width: 48, height: 60)
                        .contentShape(Rectangle())
                        .onTapGesture { focusedIndex = i }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 36)

                HStack(spacing: 8) {
                    Text("Didn't get it?")
                        .foregroundColor(DS.textDim)
                    Text("Resend in 0:42")
                        .foregroundColor(DS.accent)
                        .fontWeight(.medium)
                }
                .font(.system(size: 14))
                .padding(.top, 28)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                }

                Spacer()

                // Invisible text field that captures keyboard input
                TextField("", text: Binding(
                    get: { code },
                    set: { newValue in
                        let filtered = newValue.filter(\.isNumber)
                        var newDigits = Array(repeating: "", count: 6)
                        for (i, ch) in filtered.prefix(6).enumerated() {
                            newDigits[i] = String(ch)
                        }
                        self.digits = newDigits
                        focusedIndex = min(filtered.count, 5)
                    }
                ))
                .keyboardType(.numberPad)
                .focused($focusedIndex, equals: 0)
                .opacity(0)
                .frame(width: 1, height: 1)
                .onChange(of: code) { if $0.count == 6 { verify() } }
            }
        }
        .navigationBarHidden(true)
        .onAppear { focusedIndex = 0 }
    }

    private func verify() {
        guard isComplete, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                // Step 1: Send the code to Clerk. On success, Clerk establishes a session
                // and populates Clerk.shared.session internally.
                try await clerkSignIn.verifyCode(code)

                // Step 2: Get the JWT from the now-active session.
                // This token goes on every API request as "Authorization: Bearer <token>".
                guard let token = try await Clerk.shared.session?.getToken() else {
                    throw URLError(.userAuthenticationRequired)
                }

                // Step 3: Check if this user already has a profile in our database.
                // 200 → they do. 404 → first time — we route them to ProfileCreationView.
                let profile = try await APIClient(token: token).getMe()

                // Step 4: Update auth state. ContentView switches screens based on this.
                authManager.signIn(token: token, hasProfile: profile != nil)
                if let profile { authManager.userLoaded(profile) }
            } catch {
                // If verifyCode succeeded but a later step (getToken, getMe) failed,
                // Clerk already has an active session. Sign it out so the user can
                // restart the flow cleanly instead of hitting "already signed in".
                if Clerk.shared.session != nil {
                    try? await Clerk.shared.auth.signOut()
                }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
