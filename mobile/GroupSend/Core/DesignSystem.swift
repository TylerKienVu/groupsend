import SwiftUI

// All design tokens — single source of truth for colors, spacing, and typography.
// Matches tokens.jsx from the design mockup exactly.
enum DS {
    // Surfaces
    static let bg      = Color(hex: "#0B0B0F")
    static let surface  = Color(hex: "#15151B")
    static let surface2 = Color(hex: "#1E1E26")
    static let surface3 = Color(hex: "#272731")
    static let border      = Color.white.opacity(0.08)
    static let borderStrong = Color.white.opacity(0.14)

    // Text
    static let text    = Color(hex: "#F4F3EF")
    static let textDim  = Color(hex: "#F4F3EF").opacity(0.62)
    static let textMute = Color(hex: "#F4F3EF").opacity(0.38)

    // Brand accent — sandstone orange (sunset on red rock)
    static let accent    = Color(hex: "#FF7B3F")
    static let accentInk = Color(hex: "#1A0E07") // dark ember brown for text on accent

    // V-grade palette (V0–V10): Partiful-bright colors that map to climbing difficulty.
    // These identify climbing grades, NOT people. Never use them as avatar colors.
    static let vGrades: [Color] = [
        Color(hex: "#E5E4DF"), // V0 — chalk white
        Color(hex: "#FFD23F"), // V1 — yellow
        Color(hex: "#FF7E33"), // V2 — orange
        Color(hex: "#3CC36A"), // V3 — green
        Color(hex: "#3DA8FF"), // V4 — blue
        Color(hex: "#B061FF"), // V5 — purple
        Color(hex: "#FF4D6D"), // V6 — red/pink
        Color(hex: "#22272E"), // V7 — near-black (requires light border)
        Color(hex: "#7A6CFF"), // V8 — indigo
        Color(hex: "#FF9D2E"), // V9 — amber
        Color(hex: "#23E0C8"), // V10 — teal
    ]

    // Avatar palette (10 saturated colors): identifies people.
    // Each user picks one at signup; it appears as their dot color in the column-stack.
    static let avatarPalette: [Color] = [
        Color(hex: "#FF7E33"), Color(hex: "#FFD23F"), Color(hex: "#3CC36A"),
        Color(hex: "#3DA8FF"), Color(hex: "#B061FF"), Color(hex: "#FF4D6D"),
        Color(hex: "#23E0C8"), Color(hex: "#FF9D2E"), Color(hex: "#7A6CFF"),
        Color(hex: "#E8FF5C"),
    ]

    static let avatarPaletteHex: [String] = [
        "#FF7E33", "#FFD23F", "#3CC36A", "#3DA8FF", "#B061FF",
        "#FF4D6D", "#23E0C8", "#FF9D2E", "#7A6CFF", "#E8FF5C",
    ]

    // Corner radii
    static let rSm: CGFloat = 10
    static let rMd: CGFloat = 14
    static let rLg: CGFloat = 22

    static func vGradeColor(_ index: Int) -> Color {
        vGrades[min(max(index, 0), 10)]
    }

    // Some grade chip backgrounds are dark enough to need white text.
    static func gradeChipForeground(index: Int) -> Color {
        [4, 5, 6, 7, 8].contains(index) ? .white : Color(hex: "#0B0B0F")
    }
}

// Rhythm rank: maps session count in the last 4 weeks to a V-grade label.
// This measures consistency frequency, not actual climbing skill.
struct RhythmRank {
    let grade: String
    let gradeIndex: Int
    let label: String

    var color: Color     { DS.vGradeColor(gradeIndex) }
    var foreground: Color { DS.gradeChipForeground(index: gradeIndex) }

    static func from(sessions n: Int) -> RhythmRank {
        switch n {
        case ...1:    return .init(grade: "V0",  gradeIndex: 0, label: "Chalking up")
        case 2...3:   return .init(grade: "V1",  gradeIndex: 1, label: "Warming up")
        case 4...5:   return .init(grade: "V2",  gradeIndex: 2, label: "Showing up")
        case 6...7:   return .init(grade: "V3",  gradeIndex: 3, label: "In rotation")
        case 8...9:   return .init(grade: "V4",  gradeIndex: 4, label: "Locked in")
        case 10...11: return .init(grade: "V5",  gradeIndex: 5, label: "Sending it")
        case 12...13: return .init(grade: "V6",  gradeIndex: 6, label: "On a tear")
        case 14...15: return .init(grade: "V7",  gradeIndex: 7, label: "Crushing")
        default:      return .init(grade: "V8+", gradeIndex: 8, label: "Pro mode")
        }
    }
}
