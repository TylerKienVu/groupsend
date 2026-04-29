import SwiftUI

// Pill-shaped label that shows a V-grade with its matching palette color.
// Used in the rhythm-rank leaderboard. The grade color comes from DS.vGrades —
// that's the grade palette, not the avatar palette.
struct GradeChip: View {
    let rank: RhythmRank
    var small: Bool = false

    var body: some View {
        Text(rank.grade)
            .font(.system(size: small ? 11 : 13, weight: .semibold, design: .monospaced))
            .foregroundColor(rank.foreground)
            .padding(.horizontal, small ? 7 : 9)
            .padding(.vertical, small ? 2 : 3)
            .background(rank.color)
            // V7 (near-black) needs a visible border so the chip reads on dark backgrounds.
            .overlay(
                rank.gradeIndex == 7
                    ? Capsule().stroke(DS.borderStrong, lineWidth: 1)
                    : nil
            )
            .clipShape(Capsule())
    }
}
