import SwiftUI

struct OtpView: View {
    let phoneNumber: String
    @EnvironmentObject private var authManager: AuthManager
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
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

                Spacer()

                // Invisible text field that captures keyboard input
                TextField("", text: Binding(
                    get: { code },
                    set: { newValue in
                        let digits = newValue.filter(\.isNumber)
                        for (i, ch) in digits.prefix(6).enumerated() {
                            self.digits[i] = String(ch)
                        }
                        // Clear trailing digits if user deleted
                        for i in digits.count..<6 { self.digits[i] = "" }
                        focusedIndex = min(digits.count, 5)
                        if digits.count == 6 { verify() }
                    }
                ))
                .keyboardType(.numberPad)
                .focused($focusedIndex, equals: 0)
                .opacity(0)
                .frame(width: 1, height: 1)
            }
        }
        .navigationBarHidden(true)
        .onAppear { focusedIndex = 0 }
    }

    private func verify() {
        guard isComplete else { return }
        isLoading = true
        // TODO: Clerk signIn.attemptFirstFactor(strategy: .phoneCode(code: code))
        // Then POST /auth/verify with { token: clerkSessionToken }
        // On success: authManager.signIn(token: response.token, hasProfile: response.hasProfile)
    }
}
