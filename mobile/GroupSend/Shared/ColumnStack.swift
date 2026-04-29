import SwiftUI

// The signature visualization: a row of day-columns, each column being a vertical
// stack of colored dots. One dot = one climber who showed up that day.
//
// Design rules (from spec):
// - Dots build bottom-up. Empty placeholder slots fill from the top so every
//   column is the same height — quiet days look thin, busy days fill up.
// - Capacity = max number of members (6 on detail, 5 on home cards).
// - Overflow: if more climbers than capacity, show "+N" in the topmost slot
//   instead of the capacity-th climber dot. Only shown on the detail screen.
// - Today highlight: orange glow on every dot in the last column.
struct ColumnStack: View {
    let days: [DayColumn]
    var capacity: Int = 6
    var dotSize: CGFloat = 14
    var dotGap: CGFloat = 3
    var showOverflow: Bool = false
    var highlightLast: Bool = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                DayColumnView(
                    day: day,
                    capacity: capacity,
                    dotSize: dotSize,
                    dotGap: dotGap,
                    showOverflow: showOverflow,
                    isToday: highlightLast && idx == days.count - 1
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DayColumnView: View {
    let day: DayColumn
    let capacity: Int
    let dotSize: CGFloat
    let dotGap: CGFloat
    let showOverflow: Bool
    let isToday: Bool

    private var hasOverflow: Bool { showOverflow && day.climbers.count > capacity }
    // Visible climbers: if overflow, reserve the top slot for "+N"
    private var visible: [ClimberDot] {
        Array(day.climbers.prefix(hasOverflow ? capacity - 1 : capacity))
    }
    private var overflowCount: Int { day.climbers.count - visible.count }
    private var filledSlots: Int  { visible.count + (hasOverflow ? 1 : 0) }
    private var emptySlots: Int   { max(0, capacity - filledSlots) }

    var body: some View {
        VStack(spacing: dotGap) {
            // Empty placeholder dots at the top (keep every column the same height)
            ForEach(0..<emptySlots, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(0.025))
                    .frame(width: dotSize, height: dotSize)
            }
            // Overflow badge (replaces the topmost climber dot when count > capacity)
            if hasOverflow {
                ZStack {
                    Circle()
                        .fill(DS.surface3)
                        .overlay(Circle().stroke(DS.border, lineWidth: 1))
                    Text("+\(overflowCount)")
                        .font(.system(size: max(7, dotSize * 0.5), weight: .semibold, design: .monospaced))
                        .foregroundColor(DS.text)
                        .minimumScaleFactor(0.5)
                }
                .frame(width: dotSize, height: dotSize)
            }
            // Climber dots — colored by avatar, glowing on today's column
            ForEach(visible) { dot in
                Circle()
                    .fill(Color(hex: dot.hexColor))
                    .frame(width: dotSize, height: dotSize)
                    .shadow(
                        color: isToday ? DS.accent.opacity(0.55) : .clear,
                        radius: dotSize / 2
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}
