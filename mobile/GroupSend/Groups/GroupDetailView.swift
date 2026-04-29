import SwiftUI

struct GroupDetailView: View {
    let group: GroupModel
    @EnvironmentObject private var authManager: AuthManager

    @State private var detailGroup: GroupModel?   // reloaded with members included
    @State private var sessions: [SessionRecord] = []
    @State private var isLoading = true
    @State private var showCheckIn = false

    // ── Computed properties ───────────────────────────────────────────────

    // Last 14 days as column data for the chart
    private var days14: [DayColumn] { sessions.toDayColumns(days: 14) }

    // Day-of-week labels ("M","T","W"…) for the 14-day window, oldest → newest
    private var dayLabels: [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<14).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let name = cal.weekdaySymbols[cal.component(.weekday, from: date) - 1]
            return String(name.prefix(1))
        }
    }

    // Total group sessions in the current calendar week
    private var thisWeekCount: Int {
        let cal = Calendar.current
        return sessions.filter {
            cal.isDate($0.climbedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    // Consecutive weeks (counting back from now) that have ≥1 group session
    private var streakWeeks: Int {
        let cal = Calendar.current
        var streak = 0
        for offset in 0..<4 {
            let anchor = cal.date(byAdding: .weekOfYear, value: -offset, to: Date())!
            if sessions.contains(where: { cal.isDate($0.climbedAt, equalTo: anchor, toGranularity: .weekOfYear) }) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // The current user's own rhythm rank
    private var myRank: RhythmRank {
        let myId = authManager.currentUser?.id ?? ""
        let count = sessions.filter { $0.userId == myId }.count
        return RhythmRank.from(sessions: count)
    }

    // Members sorted by session count desc — the leaderboard order
    private var rankedMembers: [(member: GroupMembership, rank: RhythmRank, count: Int)] {
        let members = (detailGroup ?? group).members ?? []
        return members.map { m in
            let count = sessions.filter { $0.userId == m.userId }.count
            return (m, RhythmRank.from(sessions: count), count)
        }.sorted { $0.count > $1.count }
    }

    // ── Body ──────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(DS.accent)
            } else {
                mainContent
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCheckIn) {
            CheckInView(groups: [group], preselectedGroupId: group.id)
        }
        .task { await loadData() }
    }

    // ── Main content ──────────────────────────────────────────────────────

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    groupHeader
                    statTiles
                    chartSection
                    leaderboard
                    Color.clear.frame(height: 100)
                }
            }
            checkInFAB
        }
    }

    // ── Top bar (back + share/settings) ──────────────────────────────────

    private var topBar: some View {
        HStack {
            NavigationBackButton()
            Spacer()
            HStack(spacing: 8) {
                IconButton(systemName: "square.and.arrow.up") {}
                IconButton(systemName: "gearshape") {}
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 52)
    }

    // ── Group name, gym, member count ─────────────────────────────────────

    private var groupHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(DS.vGrades[3])
                    .frame(width: 7, height: 7)
                Text("Active · \((detailGroup ?? group).members?.count ?? 0) members")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DS.textDim)
                    .tracking(1)
            }
            Text(group.name)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(DS.text)
                .tracking(-0.9)
                .padding(.top, 8)
            HStack(spacing: 6) {
                Image(systemName: "mappin")
                    .font(.system(size: 12))
                    .foregroundColor(DS.textDim)
                Text(group.gymName)
                    .font(.system(size: 14))
                    .foregroundColor(DS.textDim)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // ── Stat tiles ────────────────────────────────────────────────────────

    private var statTiles: some View {
        HStack(spacing: 8) {
            StatTile(label: "This week", value: "\(thisWeekCount)", accent: DS.accent)
            StatTile(label: "Streak", value: streakWeeks > 0 ? "\(streakWeeks)w" : "—")
            StatTile(label: "You", value: myRank.grade)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    // ── Column-stack chart ────────────────────────────────────────────────

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("WHO CLIMBED WHEN")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DS.textDim)
                    .tracking(1)
                Spacer()
                Text("14d ▾")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.accent)
            }
            .padding(.bottom, 10)

            // Chart card
            VStack(spacing: 0) {
                ColumnStack(
                    days: days14,
                    capacity: 6,
                    dotSize: 14,
                    dotGap: 3,
                    showOverflow: true,
                    highlightLast: true
                )
                .frame(height: 105)

                // Day-of-week labels
                HStack(spacing: 0) {
                    ForEach(Array(dayLabels.enumerated()), id: \.offset) { idx, label in
                        Text(label)
                            .font(.system(size: 10, weight: idx == 13 ? .semibold : .regular, design: .monospaced))
                            .foregroundColor(idx == 13 ? DS.accent : DS.textDim)
                            .tracking(0.4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 10)

                HStack {
                    Text("2 WEEKS AGO")
                    Spacer()
                    Text("TODAY")
                }
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(DS.textMute)
                .tracking(0.6)
                .padding(.top, 4)
            }
            .padding(14)
            .background(DS.surface)
            .overlay(RoundedRectangle(cornerRadius: DS.rLg).stroke(DS.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: DS.rLg))

            Text("Each dot is a climber. Stack stays low when the crew skips, tall when everyone shows.")
                .font(.system(size: 12))
                .foregroundColor(DS.textDim)
                .lineSpacing(3)
                .padding(.horizontal, 4)
                .padding(.top, 10)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }

    // ── Rhythm rank leaderboard ───────────────────────────────────────────

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("RHYTHM RANK")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(DS.textDim)
                    .tracking(1)
                Spacer()
                Text("4w")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.accent)
            }
            .padding(.bottom, 4)

            Text("Earned from sessions in the last 4 weeks. Keep showing up to level up.")
                .font(.system(size: 12))
                .foregroundColor(DS.textDim)
                .lineSpacing(3)
                .padding(.horizontal, 4)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(rankedMembers.enumerated()), id: \.element.member.userId) { idx, entry in
                    leaderboardRow(rank: idx + 1, entry: entry)
                    if idx < rankedMembers.count - 1 {
                        Divider().background(DS.border).padding(.leading, 56)
                    }
                }
            }
            .background(DS.surface)
            .overlay(RoundedRectangle(cornerRadius: DS.rLg).stroke(DS.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: DS.rLg))
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
    }

    private func leaderboardRow(rank: Int, entry: (member: GroupMembership, rank: RhythmRank, count: Int)) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(DS.textMute)
                .frame(width: 14, alignment: .center)

            AvatarView(name: entry.member.user.name, hexColor: entry.member.user.avatarColor, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.member.user.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DS.text)
                Text("\(entry.count) sessions · 4w")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(DS.textDim)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                GradeChip(rank: entry.rank, small: true)
                Text(entry.rank.label.uppercased())
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(DS.textMute)
                    .tracking(0.6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // ── Check-in FAB ──────────────────────────────────────────────────────

    private var checkInFAB: some View {
        Button { showCheckIn = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(DS.accentInk).frame(width: 30, height: 30)
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DS.accent)
                }
                Text("I climbed today")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.accentInk)
            }
            .padding(.leading, 18)
            .padding(.trailing, 26)
            .frame(height: 54)
            .background(DS.accent)
            .clipShape(Capsule())
            .shadow(color: DS.accent.opacity(0.4), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
        }
        .padding(.bottom, 28)
    }

    // ── Data loading ──────────────────────────────────────────────────────

    private func loadData() async {
        let api = authManager.apiClient()
        async let detail: GroupModel = api.get("/groups/\(group.id)")
        async let sessionsResp: SessionsResponse = api.get("/sessions", query: ["groupId": group.id, "weeks": "4"])
        do {
            let (d, s) = try await (detail, sessionsResp)
            await MainActor.run {
                detailGroup = d
                sessions = s.sessions
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// ── Reusable sub-components ───────────────────────────────────────────────

private struct StatTile: View {
    let label: String
    let value: String
    var accent: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(DS.textDim)
                .tracking(0.8)
            Text(value)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(accent ?? DS.text)
                .tracking(-0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DS.surface)
        .overlay(RoundedRectangle(cornerRadius: DS.rMd).stroke(DS.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.rMd))
    }
}

private struct IconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundColor(DS.text)
                .frame(width: 36, height: 36)
                .background(DS.surface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.border, lineWidth: 1))
        }
    }
}

// Shared back-button that pops the navigation stack
struct NavigationBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DS.text)
                .frame(width: 36, height: 36)
                .background(DS.surface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.border, lineWidth: 1))
        }
    }
}
