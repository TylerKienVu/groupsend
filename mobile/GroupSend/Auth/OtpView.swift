import SwiftUI
import ClerkKit

private enum OTPState { case entering, verifying, success, error }

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = animatableData - animatableData.rounded(.down)
        let x = sin(t * .pi * 6) * 6 * max(0, 1 - t)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

struct OtpView: View {
    let phoneNumber: String
    let clerkSignIn: SignIn
    @EnvironmentObject private var authManager: AuthManager

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var otpState: OTPState = .entering
    @FocusState private var keyboardActive: Bool

    @State private var isPulsing = false
    @State private var shakeAmount: CGFloat = 0
    @State private var successScale: CGFloat = 0.6
    @State private var successOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var code: String { digits.joined() }
    private var activeIndex: Int { digits.firstIndex(of: "") ?? 5 }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────
                HStack {
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

                // ── Copy ──────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter the code")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(DS.text)
                        .tracking(-0.9)

                    HStack(spacing: 4) {
                        Text("Sent to").foregroundColor(DS.textDim)
                        Text(phoneNumber).foregroundColor(DS.text)
                    }
                    .font(.system(size: 15))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 12)

                // ── Digit row ─────────────────────────────────────────────
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { i in
                        OTPDigitCell(
                            digit: digits[i],
                            index: i,
                            activeIndex: activeIndex,
                            otpState: otpState,
                            isPulsing: isPulsing,
                            reduceMotion: reduceMotion,
                            onTap: { keyboardActive = true }
                        )
                    }
                }
                .modifier(ShakeEffect(animatableData: shakeAmount))
                .padding(.horizontal, 28)
                .padding(.top, 36)

                // ── Caption + subline ─────────────────────────────────────
                OTPCaptionRow(
                    otpState: otpState,
                    isPulsing: isPulsing,
                    successScale: successScale,
                    successOpacity: successOpacity,
                    reduceMotion: reduceMotion
                )
                .font(.system(size: 14))
                .padding(.horizontal, 28)
                .padding(.top, 28)

                Spacer()

                // ── Hidden text field — keyboard capture ──────────────────
                TextField("", text: Binding(
                    get: { code },
                    set: { newValue in
                        guard otpState == .entering else { return }
                        let filtered = newValue.filter(\.isNumber)
                        var newDigits = Array(repeating: "", count: 6)
                        for (i, ch) in filtered.prefix(6).enumerated() {
                            newDigits[i] = String(ch)
                        }
                        digits = newDigits
                    }
                ))
                .keyboardType(.numberPad)
                .focused($keyboardActive)
                .opacity(0)
                .frame(width: 1, height: 1)
            }
        }
        .navigationBarHidden(true)
        .onAppear { keyboardActive = true }
        .onChange(of: code) { _, newCode in
            if newCode.count == 6, otpState == .entering { startVerifying() }
        }
        .onChange(of: otpState) { _, newState in handleStateChange(newState) }
    }

    private func handleStateChange(_ state: OTPState) {
        switch state {
        case .entering:
            successScale = 0.6
            successOpacity = 0

        case .verifying:
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }

        case .success:
            isPulsing = false
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                successScale = 1
                successOpacity = 1
            }

        case .error:
            isPulsing = false
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.5)) { shakeAmount += 1 }
        }
    }

    private func startVerifying() {
        let capturedCode = code
        otpState = .verifying

        Task {
            do {
                try await clerkSignIn.verifyCode(capturedCode)
                guard let token = try await Clerk.shared.session?.getToken() else {
                    throw URLError(.userAuthenticationRequired)
                }
                let profile = try await APIClient(token: token).getMe()

                await MainActor.run { otpState = .success }
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run {
                    authManager.signIn(token: token, hasProfile: profile != nil)
                    if let profile { authManager.userLoaded(profile) }
                }

            } catch {
                if Clerk.shared.session != nil {
                    try? await Clerk.shared.auth.signOut()
                }
                await MainActor.run { otpState = .error }
                try? await Task.sleep(for: .milliseconds(450))
                await MainActor.run {
                    digits = Array(repeating: "", count: 6)
                    otpState = .entering
                    keyboardActive = true
                }
            }
        }
    }
}

// ── OTPDigitCell ──────────────────────────────────────────────────────────────

private struct OTPDigitCell: View {
    let digit: String
    let index: Int
    let activeIndex: Int
    let otpState: OTPState
    let isPulsing: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.rMd)
                .fill(cellFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.rMd)
                        .stroke(cellBorder, lineWidth: cellBorderWidth)
                )
                .shadow(color: cellShadow, radius: 8)

            if digit.isEmpty && index == activeIndex && otpState == .entering {
                Rectangle()
                    .fill(DS.accent)
                    .frame(width: 2, height: 24)
            } else {
                Text(digit)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .foregroundColor(cellTextColor)
            }
        }
        .frame(width: 48, height: 60)
        .offset(y: otpState == .verifying && isPulsing ? -3 : 0)
        .animation(
            !reduceMotion && otpState == .verifying
                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(index) * 0.18)
                : .linear(duration: 0),
            value: isPulsing
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var cellFill: Color {
        switch otpState {
        case .success: return DS.success.opacity(0.10)
        case .error:   return DS.error.opacity(0.08)
        default:       return DS.surface
        }
    }

    private var cellBorder: Color {
        switch otpState {
        case .entering:
            if index == activeIndex { return DS.accent }
            return digit.isEmpty ? DS.border : DS.borderStrong
        case .verifying:
            return isPulsing ? DS.accent : DS.borderStrong
        case .success:
            return DS.success
        case .error:
            return DS.error
        }
    }

    private var cellBorderWidth: CGFloat {
        otpState == .entering && index == activeIndex ? 2 : 1
    }

    private var cellShadow: Color {
        switch otpState {
        case .entering:
            return index == activeIndex ? DS.accent.opacity(0.2) : .clear
        case .verifying:
            return isPulsing ? DS.accent.opacity(0.33) : .clear
        case .success:
            return DS.success.opacity(0.33)
        case .error:
            return DS.error.opacity(0.4)
        }
    }

    private var cellTextColor: Color {
        otpState == .error ? DS.error : DS.text
    }
}

// ── OTPCaptionRow ─────────────────────────────────────────────────────────────

private struct OTPCaptionRow: View {
    let otpState: OTPState
    let isPulsing: Bool
    let successScale: CGFloat
    let successOpacity: Double
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                captionContent
            }
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)

            if otpState == .verifying {
                Text("Checking with carrier")
                    .font(.system(size: 13))
                    .foregroundColor(DS.textMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var captionContent: some View {
        switch otpState {
        case .entering:
            Text("Didn't get it?").foregroundColor(DS.textDim)
            Text("Resend in 0:42").foregroundColor(DS.accent).fontWeight(.medium)

        case .verifying:
            Text("Verifying").foregroundColor(DS.text)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(DS.accent).frame(width: 4, height: 4)
                        .offset(y: isPulsing ? -2 : 0)
                        .animation(
                            .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: isPulsing
                        )
                }
            }

        case .success:
            ZStack {
                Circle().fill(DS.success).frame(width: 18, height: 18)
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                    .foregroundColor(DS.bg)
            }
            .scaleEffect(successScale).opacity(successOpacity)
            Text("Verified").foregroundColor(DS.success).fontWeight(.medium)

        case .error:
            Text("That code didn't match.").foregroundColor(DS.error).fontWeight(.medium)
            Spacer()
            Text("Resend").foregroundColor(DS.accent).fontWeight(.medium)
        }
    }
}
