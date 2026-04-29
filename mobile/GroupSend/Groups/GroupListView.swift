import SwiftUI

// Accent colors assigned to groups in order — cycles through a subset of V-grade colors.
// These are purely cosmetic; they don't encode climbing grade.
private let groupAccents: [Color] = [DS.vGrades[3], DS.vGrades[9], DS.vGrades[5], DS.vGrades[4], DS.vGrades[6]]

struct GroupListView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var pendingCheckinGroupId: String?

    @State private var groups: [GroupModel] = []
    @State private var sessionsByGroup: [String: [DayColumn]] = [:]  // groupId → 10-day columns
    @State private var showCreateGroup = false
    @State private var showCheckIn = false
    @State private var checkinGroupId: String? = nil
    @State private var showSettings = false
    @State private var isLoading = true
    @State private var selectedGroup: GroupModel?

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if groups.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }
            .navigationDestination(item: $selectedGroup) { group in
                GroupDetailView(group: group)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            GroupCreationView()
        }
        .sheet(isPresented: $showCheckIn, onDismiss: { checkinGroupId = nil }) {
            CheckInView(groups: groups, preselectedGroupId: checkinGroupId)
        }
        .onChange(of: pendingCheckinGroupId) { groupId in
            guard let groupId, !groups.isEmpty else { return }
            checkinGroupId = groupId
            showCheckIn = true
            pendingCheckinGroupId = nil
        }
        .task { await loadGroups() }
    }

    // ── Loading ───────────────────────────────────────────────────────────
    private var loadingView: some View {
        ProgressView()
            .tint(DS.accent)
    }

    // ── Empty state ───────────────────────────────────────────────────────
    private var emptyState: some View {
        ZStack {
            ContourBackground(opacity: 0.09)

            VStack(spacing: 0) {
                header

                Spacer()

                VStack(spacing: 0) {
                    // Jug icon with "0/0" badge
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 26)
                                .fill(DS.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26)
                                        .stroke(DS.border, lineWidth: 1)
                                )
                            Image(systemName: "figure.climbing")
                                .font(.system(size: 48))
                                .foregroundColor(DS.accent)
                        }
                        .frame(width: 88, height: 88)

                        Text("0/0")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(DS.accentInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DS.accent)
                            .clipShape(Capsule())
                            .offset(x: 8, y: 8)
                    }

                    Text("No crew yet")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(DS.text)
                        .tracking(-0.8)
                        .multilineTextAlignment(.center)
                        .padding(.top, 28)

                    Text("GroupSend is no fun solo. Start a group with your climbing friends or join one with an invite link.")
                        .font(.system(size: 15))
                        .foregroundColor(DS.textDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)

                    VStack(spacing: 10) {
                        Button { showCreateGroup = true } label: {
                            Label("Start a group", systemImage: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(DS.accentInk)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(DS.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        Button {} label: {
                            Text("Paste invite link")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(DS.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(DS.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(DS.borderStrong, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, 28)

                Spacer()
            }
        }
    }

    // ── Group list ────────────────────────────────────────────────────────
    private var groupList: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    // "Your crews" heading + summary line
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your crews")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(DS.text)
                            .tracking(-0.9)
                        Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
                            .font(.system(size: 14))
                            .foregroundColor(DS.textDim)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                    // Group cards
                    VStack(spacing: 12) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { idx, group in
                            GroupCard(
                                group: group,
                                days: sessionsByGroup[group.id],
                                accentColor: groupAccents[idx % groupAccents.count],
                                onTap: { selectedGroup = group }
                            )
                        }

                        // "New group" dashed card
                        Button { showCreateGroup = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14))
                                Text("New group")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(DS.textDim)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.rLg)
                                    .stroke(DS.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 120) // clearance for FAB
                }
            }

            // ── Check-in FAB ─────────────────────────────────────────────
            Button { showCheckIn = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(DS.accentInk)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DS.accent)
                    }
                    Text("Check in")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.accentInk)
                }
                .padding(.leading, 14)
                .padding(.trailing, 22)
                .frame(height: 52)
                .background(DS.accent)
                .clipShape(Capsule())
                .shadow(color: DS.accent.opacity(0.4), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            }
            .padding(.bottom, 28)
        }
    }

    // ── Shared header ─────────────────────────────────────────────────────
    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                // App logo mark
                Text("g/")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DS.accentInk)
                    .frame(width: 32, height: 32)
                    .background(DS.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                // Current user avatar — tapping opens settings
                if let user = authManager.currentUser {
                    Button { showSettings = true } label: {
                        AvatarView(name: user.name, hexColor: user.avatarColor, size: 32)
                    }
                }
            }
            Spacer()
            // Bell icon button
            Button {} label: {
                Image(systemName: "bell")
                    .font(.system(size: 16))
                    .foregroundColor(DS.text)
                    .frame(width: 36, height: 36)
                    .background(DS.surface2)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 52)
    }

    // ── Data loading ──────────────────────────────────────────────────────
    private func loadGroups() async {
        let api = authManager.apiClient()
        do {
            let response: GroupListResponse = try await api.get("/groups")
            await MainActor.run {
                groups = response.groups
                isLoading = false
                // Handle notification deep link that arrived before groups loaded
                if let groupId = pendingCheckinGroupId {
                    checkinGroupId = groupId
                    showCheckIn = true
                    pendingCheckinGroupId = nil
                }
            }
            // Load sessions for each group in parallel so the column-stacks fill in
            await withTaskGroup(of: (String, [DayColumn]).self) { taskGroup in
                for group in response.groups {
                    taskGroup.addTask {
                        let cols = await loadDayColumns(for: group.id, api: api)
                        return (group.id, cols)
                    }
                }
                for await (groupId, cols) in taskGroup {
                    await MainActor.run { sessionsByGroup[groupId] = cols }
                }
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func loadDayColumns(for groupId: String, api: APIClient) async -> [DayColumn] {
        do {
            let response: SessionsResponse = try await api.get(
                "/sessions",
                query: ["groupId": groupId, "weeks": "2"]
            )
            return response.sessions.toDayColumns(days: 10)
        } catch {
            return []
        }
    }
}
