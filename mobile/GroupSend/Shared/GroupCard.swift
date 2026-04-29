import SwiftUI

// Home screen card for a single group.
// Shows: group name, gym, member avatar row, and a 10-day mini column-stack.
// The colored top bar uses the group's accent color (one of the V-grade colors).
struct GroupCard: View {
    let group: GroupModel
    // Days is loaded asynchronously by the parent after the group list loads.
    // If nil, the column-stack area shows an empty placeholder.
    var days: [DayColumn]?
    var accentColor: Color = DS.vGrades[3] // default: V3 green
    var onTap: () -> Void = {}

    private var members: [GroupMembership] { group.members ?? [] }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Colored top accent bar
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 3)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DS.text)
                                .tracking(-0.4)
                            HStack(spacing: 5) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 11))
                                    .foregroundColor(DS.textDim)
                                Text(group.gymName)
                                    .font(.system(size: 13))
                                    .foregroundColor(DS.textDim)
                            }
                        }
                        Spacer()
                        // Overlapping member avatars (up to 4, then "+N")
                        memberAvatars
                    }
                    .padding(.top, 14)

                    // 10-day mini column-stack
                    let placeholder = (0..<10).map { i in
                        DayColumn(id: "\(i)", date: Date(), climbers: [])
                    }
                    ColumnStack(
                        days: days ?? placeholder,
                        capacity: 5,
                        dotSize: 8,
                        dotGap: 2,
                        showOverflow: false,
                        highlightLast: days != nil
                    )
                    .frame(height: 56)
                    .padding(.top, 14)

                    HStack {
                        Text("10D AGO")
                        Spacer()
                        Text("TODAY")
                    }
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(DS.textMute)
                    .tracking(0.6)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .background(DS.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DS.rLg)
                    .stroke(DS.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.rLg))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var memberAvatars: some View {
        let visible = Array(members.prefix(4))
        let extra = max(0, members.count - 4)
        ZStack(alignment: .trailing) {
            HStack(spacing: -8) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, m in
                    AvatarView(name: m.user.name, hexColor: m.user.avatarColor, size: 26, ring: true)
                }
                if extra > 0 {
                    ZStack {
                        Circle().fill(DS.surface3)
                            .overlay(Circle().stroke(DS.bg, lineWidth: 2.5))
                        Text("+\(extra)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(DS.textDim)
                    }
                    .frame(width: 26, height: 26)
                }
            }
        }
    }
}
