import SwiftUI

// Shown when the user taps a groupsend://invite/:code deep link.
// Loads public group info (no auth required for GET /invite/:code),
// then lets the user join after authenticating.
struct InviteView: View {
    let inviteCode: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var info: InviteInfo?
    @State private var days: [DayColumn] = []
    @State private var isLoading = true
    @State private var isJoining = false
    @State private var joined = false
    @State private var error: String?

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            ContourBackground(opacity: 0.08, color: DS.vGrades[9])

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DS.text)
                            .frame(width: 36, height: 36)
                            .background(DS.surface2)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DS.border, lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)

                if isLoading {
                    Spacer()
                    ProgressView().tint(DS.accent)
                    Spacer()
                } else if let info {
                    inviteContent(info: info)
                } else {
                    errorState
                }
            }
        }
        .task { await loadInvite() }
    }

    // ── Invite content ────────────────────────────────────────────────────

    private func inviteContent(info: InviteInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // "YOU'RE INVITED" eyebrow
                Text("YOU'RE INVITED")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(DS.vGrades[9])
                    .tracking(1.2)
                    .padding(.bottom, 14)

                // Placeholder stacked avatars (we don't have real member data from the public endpoint)
                placeholderAvatars(count: min(info.memberCount, 5))
                    .padding(.bottom, 16)

                // Group name + invite copy
                Text(info.name)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(DS.text)
                    .tracking(-0.9)

                Text("You've been invited to log climbs together at \(info.gymName).")
                    .font(.system(size: 15))
                    .foregroundColor(DS.textDim)
                    .lineSpacing(4)
                    .padding(.top, 10)

                // Info chips
                HStack(spacing: 8) {
                    infoChip(icon: "mappin", label: "\(info.gymName)")
                    infoChip(icon: "person.2", label: "\(info.memberCount) climbers")
                }
                .padding(.top, 22)

                // Mini column-stack preview
                if !days.isEmpty {
                    chartPreview
                        .padding(.top, 22)
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 140) // clearance for CTA
        }
        .overlay(alignment: .bottom) {
            ctaButtons(info: info)
        }
    }

    // ── Mini chart preview ─────────────────────────────────────────────────

    private var chartPreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("THE LAST 14 DAYS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DS.textDim)
                    .tracking(1)
                Spacer()
            }
            .padding(.bottom, 10)

            ColumnStack(
                days: days,
                capacity: 6,
                dotSize: 8,
                dotGap: 2.5,
                showOverflow: false,
                highlightLast: false
            )
            .frame(height: 80)

            HStack {
                Text("2W AGO")
                Spacer()
                Text("YESTERDAY")
            }
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .foregroundColor(DS.textMute)
            .tracking(0.6)
            .padding(.top, 8)
        }
        .padding(14)
        .background(DS.surface)
        .overlay(RoundedRectangle(cornerRadius: DS.rLg).stroke(DS.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg))
    }

    // ── CTA buttons ───────────────────────────────────────────────────────

    private func ctaButtons(info: InviteInfo) -> some View {
        VStack(spacing: 10) {
            Button {
                joinGroup()
            } label: {
                Group {
                    if isJoining {
                        ProgressView().tint(DS.accentInk)
                    } else if joined {
                        Label("Joined!", systemImage: "checkmark")
                    } else {
                        Text("Join the crew")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DS.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DS.accent)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(isJoining || joined)

            Button { dismiss() } label: {
                Text("Maybe later")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DS.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DS.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(DS.borderStrong, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 36)
        .background(
            LinearGradient(
                colors: [DS.bg.opacity(0), DS.bg],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // ── Error state ───────────────────────────────────────────────────────

    private var errorState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Invalid invite link")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DS.text)
            Text("This invite may have expired or the group no longer exists.")
                .font(.system(size: 15))
                .foregroundColor(DS.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { dismiss() } label: {
                Text("Go back")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DS.accentInk)
                    .frame(width: 160)
                    .frame(height: 52)
                    .background(DS.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
        }
    }

    // ── Small helpers ─────────────────────────────────────────────────────

    private func placeholderAvatars(count: Int) -> some View {
        HStack(spacing: -10) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(DS.avatarPalette[i % DS.avatarPalette.count])
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(DS.bg, lineWidth: 2.5))
            }
        }
    }

    private func infoChip(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(DS.textDim)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DS.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(DS.surface)
        .overlay(Capsule().stroke(DS.border, lineWidth: 1))
        .clipShape(Capsule())
    }

    // ── Data loading + join ───────────────────────────────────────────────

    private func loadInvite() async {
        // GET /invite/:code is public — no auth token needed
        let api = APIClient()
        do {
            let result: InviteInfo = try await api.get("/invite/\(inviteCode)")
            await MainActor.run {
                info = result
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func joinGroup() {
        isJoining = true
        let api = authManager.apiClient()
        Task {
            do {
                struct Empty: Encodable {}
                let _: GroupModel = try await api.post("/groups/join/\(inviteCode)", body: Empty())
                await MainActor.run {
                    isJoining = false
                    joined = true
                }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { isJoining = false }
            }
        }
    }
}
