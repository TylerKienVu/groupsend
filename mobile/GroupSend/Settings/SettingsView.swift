import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var historyReminders = true
    @State private var crewCheckIns = false
    @State private var sound = true

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Nav ─────────────────────────────────────────────────
                HStack {
                    NavigationBackButton()
                    Spacer()
                    Text("Settings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.text)
                    Spacer()
                    Color.clear.frame(width: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Profile card ─────────────────────────────────
                        if let user = authManager.currentUser {
                            profileCard(user: user)
                                .padding(.top, 20)
                        }

                        // ── Notifications ─────────────────────────────────
                        sectionHeader("Notifications")
                            .padding(.top, 22)

                        settingsList {
                            toggleRow(
                                title: "History reminders",
                                subtitle: "Ping me when I climbed last week",
                                isOn: $historyReminders,
                                onChange: { enabled in
                                    Task {
                                        if enabled {
                                            // Re-request permission and re-register
                                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                                                guard granted else { return }
                                                DispatchQueue.main.async {
                                                    UIApplication.shared.registerForRemoteNotifications()
                                                }
                                            }
                                        } else {
                                            await authManager.clearDeviceToken()
                                        }
                                    }
                                }
                            )
                            Divider().background(DS.border)
                            toggleRow(
                                title: "Crew check-ins",
                                subtitle: "When friends log a session",
                                isOn: $crewCheckIns
                            )
                            Divider().background(DS.border)
                            toggleRow(title: "Sound", isOn: $sound)
                        }

                        Text("We only ping you on days you climbed last week. No streaks, no nagging.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.textMute)
                            .lineSpacing(3)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                            .padding(.bottom, 16)

                        // ── Account ───────────────────────────────────────
                        sectionHeader("Account")
                            .padding(.top, 6)

                        settingsList {
                            ForEach(["Edit profile", "Privacy", "Data & export", "Help"], id: \.self) { label in
                                navRow(label: label)
                                if label != "Help" {
                                    Divider().background(DS.border)
                                }
                            }
                        }
                        .padding(.bottom, 22)

                        // ── Sign out ──────────────────────────────────────
                        Button { authManager.signOut() } label: {
                            Text("Sign out")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(DS.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // Version
                        Text("GROUPSEND · v0.1.0")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(DS.textMute)
                            .tracking(1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 22)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // ── Profile card ──────────────────────────────────────────────────────

    private func profileCard(user: UserProfile) -> some View {
        HStack(spacing: 14) {
            AvatarView(name: user.name, hexColor: user.avatarColor, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DS.text)
                    .tracking(-0.3)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(DS.textDim)
        }
        .padding(16)
        .background(DS.surface)
        .overlay(RoundedRectangle(cornerRadius: DS.rLg).stroke(DS.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg))
    }

    // ── Section header ────────────────────────────────────────────────────

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(DS.textDim)
            .tracking(1)
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
    }

    // ── Settings list card wrapper ────────────────────────────────────────

    @ViewBuilder
    private func settingsList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(DS.surface)
        .overlay(RoundedRectangle(cornerRadius: DS.rLg).stroke(DS.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg))
    }

    // ── Toggle row ────────────────────────────────────────────────────────

    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>, onChange: ((Bool) -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(DS.text)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(DS.textDim)
                }
            }
            Spacer()
            // Custom toggle styled to match the design (accent on / surface3 off)
            ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                Capsule()
                    .fill(isOn.wrappedValue ? DS.accent : DS.surface3)
                    .frame(width: 44, height: 26)
                Circle()
                    .fill(isOn.wrappedValue ? DS.accentInk : .white)
                    .frame(width: 22, height: 22)
                    .padding(2)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.2)) { isOn.wrappedValue.toggle() }
                onChange?(isOn.wrappedValue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // ── Nav row ───────────────────────────────────────────────────────────

    private func navRow(label: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(DS.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(DS.textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
