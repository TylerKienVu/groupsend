import SwiftUI

struct CheckInView: View {
    let groups: [GroupModel]
    var preselectedGroupId: String? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var selectedGroupId: String
    @State private var isLoading = false
    @State private var didCheckIn = false

    // Current week: Mon–Sun, with today flagged
    private let weekDays: [(label: String, date: Date)] = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        // Distance from Monday (weekday 2) to today
        let distFromMonday = (weekday - 2 + 7) % 7
        let monday = cal.date(byAdding: .day, value: -distFromMonday, to: today)!
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: monday)!
            let sym = cal.shortWeekdaySymbols[(cal.component(.weekday, from: date) - 1)]
            return (String(sym.prefix(1)).uppercased(), date)
        }
    }()

    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }

    init(groups: [GroupModel], preselectedGroupId: String? = nil) {
        self.groups = groups
        self.preselectedGroupId = preselectedGroupId
        // Default to preselected group, or first group in list
        _selectedGroupId = State(initialValue: preselectedGroupId ?? groups.first?.id ?? "")
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            ContourBackground(opacity: 0.06)

            VStack(spacing: 0) {
                // ── Nav ─────────────────────────────────────────────────
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
                    Text("Check in")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.text)
                    Spacer()
                    Color.clear.frame(width: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)

                // ── Group selector ───────────────────────────────────────
                if groups.count > 1 || preselectedGroupId == nil {
                    groupPicker
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                }

                // ── Big check-in button ──────────────────────────────────
                Spacer()
                checkInCircle
                Spacer()

                // ── This-week retroactive strip ───────────────────────────
                weekStrip
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
            }
        }
    }

    // ── Group picker ──────────────────────────────────────────────────────

    private var groupPicker: some View {
        Menu {
            ForEach(groups) { g in
                Button(g.name) { selectedGroupId = g.id }
            }
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DS.vGrades[3])
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 14))
                            .foregroundColor(DS.accentInk)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(groups.first(where: { $0.id == selectedGroupId })?.name ?? "Select group")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.text)
                    if let gym = groups.first(where: { $0.id == selectedGroupId })?.gymName {
                        Text(gym)
                            .font(.system(size: 11))
                            .foregroundColor(DS.textDim)
                    }
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13))
                    .foregroundColor(DS.textDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(DS.surface)
            .overlay(RoundedRectangle(cornerRadius: DS.rMd).stroke(DS.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: DS.rMd))
        }
    }

    // ── Big check-in circle ───────────────────────────────────────────────

    private var checkInCircle: some View {
        VStack(spacing: 0) {
            ZStack {
                // Pulse rings
                ForEach([0, 1, 2], id: \.self) { i in
                    Circle()
                        .stroke(DS.accent, lineWidth: 1)
                        .opacity(0.18 - Double(i) * 0.05)
                        .frame(width: 200 + CGFloat(i) * 40, height: 200 + CGFloat(i) * 40)
                }
                // Main button
                Circle()
                    .fill(didCheckIn ? DS.surface2 : DS.accent)
                    .frame(width: 200, height: 200)
                    .shadow(color: DS.accent.opacity(0.45), radius: 30, x: 0, y: 12)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: didCheckIn ? "checkmark.seal.fill" : "checkmark")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(didCheckIn ? DS.accent : DS.accentInk)
                            Text(didCheckIn ? "Logged!" : "I climbed")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(didCheckIn ? DS.text : DS.accentInk)
                                .tracking(-0.5)
                        }
                    )
            }
            .onTapGesture { logToday() }
            .disabled(isLoading || didCheckIn)

            // Current date + time
            Text(todayLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(DS.textDim)
                .tracking(1)
                .padding(.top, 28)
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d · h:mm a"
        return f.string(from: Date()).uppercased()
    }

    // ── Week strip ────────────────────────────────────────────────────────

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OR LOG ANOTHER DAY")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(DS.textDim)
                .tracking(1)

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.label) { day in
                    let isToday = Calendar.current.isDateInToday(day.date)
                    let isFuture = day.date > todayStart

                    VStack(spacing: 6) {
                        Text(day.label)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(isToday ? DS.accent : DS.textDim)
                            .tracking(0.6)

                        // Placeholder box — tapping logs that day retroactively
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isFuture ? Color.clear : DS.accent.opacity(isToday ? 0 : 0))
                            .stroke(isFuture ? DS.border.opacity(0.3) : DS.borderStrong,
                                    style: StrokeStyle(lineWidth: 1, dash: isFuture ? [4, 3] : []))
                            .frame(width: 22, height: 22)
                            .overlay(
                                isFuture ? nil : Image(systemName: "plus")
                                    .font(.system(size: 10))
                                    .foregroundColor(DS.textMute)
                            )
                            .onTapGesture {
                                guard !isFuture else { return }
                                logSession(on: day.date)
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isToday ? DS.accent.opacity(0.13) : DS.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rMd)
                            .stroke(isToday ? DS.accent.opacity(0.32) : DS.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.rMd))
                }
            }
        }
    }

    // ── API calls ─────────────────────────────────────────────────────────

    private func logToday() {
        logSession(on: Date())
    }

    private func logSession(on date: Date) {
        guard !selectedGroupId.isEmpty else { return }
        isLoading = true
        let api = authManager.apiClient()
        Task {
            do {
                struct Body: Encodable {
                    let groupId: String
                    let climbedAt: String
                }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                let _: SessionRecord = try await api.post(
                    "/sessions",
                    body: Body(groupId: selectedGroupId, climbedAt: formatter.string(from: date))
                )
                await MainActor.run {
                    isLoading = false
                    didCheckIn = true
                }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
