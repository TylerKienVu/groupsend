import SwiftUI
import ClerkKit

enum ClerkAuthAttempt {
    case signIn(SignIn)
    case signUp(SignUp)
}

struct PhoneEntryView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var authAttempt: ClerkAuthAttempt?
    @State private var showOTP = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ContourBackground(opacity: 0.07)

                VStack(spacing: 0) {
                    // ── Hero copy ────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        // App logo mark
                        Text("g/")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(DS.accentInk)
                            .frame(width: 68, height: 68)
                            .background(DS.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: DS.accent.opacity(0.3), radius: 12, x: 0, y: 8)

                        // Headline — two lines, second line dimmed
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Climb together.")
                                .foregroundColor(DS.text)
                            Text("Show up consistently.")
                                .foregroundColor(DS.textDim)
                        }
                        .font(.system(size: 36, weight: .semibold))
                        .tracking(-1)
                        .padding(.top, 32)

                        Text("A check-in app for climbing crews. No streaks. No points. Just a heatmap of who's been showing up.")
                            .font(.system(size: 15))
                            .foregroundColor(DS.textDim)
                            .lineSpacing(4)
                            .padding(.top, 18)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 90)

                    Spacer()

                    // ── Phone input + CTA ────────────────────────────────────
                    VStack(spacing: 0) {
                        Text("PHONE NUMBER")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(DS.textDim)
                            .tracking(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)

                        HStack(spacing: 10) {
                            // Flag + country code
                            HStack(spacing: 4) {
                                Text("🇺🇸").font(.system(size: 17))
                                Text("+1")
                                    .font(.system(size: 17))
                                    .foregroundColor(DS.textDim)
                            }
                            Rectangle()
                                .fill(DS.border)
                                .frame(width: 1, height: 22)
                            TextField("(555) 000-0000", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .font(.system(size: 19))
                                .foregroundColor(DS.text)
                                .focused($fieldFocused)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(DS.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.rLg)
                                .stroke(DS.borderStrong, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg))

                        Button {
                            sendCode()
                        } label: {
                            Text("Send code")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(DS.accentInk)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(phoneNumber.isEmpty || isLoading ? DS.accent.opacity(0.5) : DS.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .disabled(phoneNumber.isEmpty || isLoading)
                        .padding(.top, 22)

                        Text("By tapping **Send code**, you agree to our **Terms** and **Privacy Policy**. Standard rates may apply.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.textMute)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 8)
                            .padding(.top, 16)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
                }
            }
            // SignIn is not Hashable so we can't use navigationDestination(item:).
            // Instead we pair a Bool trigger with the optional SignIn object.
            .navigationDestination(isPresented: $showOTP) {
                if let attempt = authAttempt {
                    OtpView(phoneNumber: phoneNumber, authAttempt: attempt)
                }
            }
            .onAppear { fieldFocused = true }
        }
    }

    private func sendCode() {
        guard !phoneNumber.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if Clerk.shared.session != nil {
                    try? await Clerk.shared.auth.signOut()
                }
                let digits = phoneNumber.filter(\.isNumber)
                let formattedNumber = "+1\(digits)"
                do {
                    let signIn = try await Clerk.shared.auth.signInWithPhoneCode(phoneNumber: formattedNumber)
                    authAttempt = .signIn(signIn)
                } catch let clerkError as ClerkAPIError where ["form_identifier_not_found", "invitation_account_not_exists"].contains(clerkError.code) {
                    let signUp = try await Clerk.shared.auth.signUp(phoneNumber: formattedNumber)
                    let preparedSignUp = try await signUp.sendPhoneCode()
                    authAttempt = .signUp(preparedSignUp)
                }
                showOTP = true
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
