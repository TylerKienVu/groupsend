import SwiftUI

// Filled circle with the user's initials. The colored fill IS the identity —
// each user picks one color from the avatar palette at signup.
struct AvatarView: View {
    let name: String
    let hexColor: String
    var size: CGFloat = 44
    // `ring` draws a bg-colored border, useful when avatars overlap (invite screen).
    var ring: Bool = false

    private var initials: String {
        name.components(separatedBy: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: hexColor))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundColor(Color(hex: "#0B0B0F"))
                .tracking(-0.5)
        }
        .frame(width: size, height: size)
        // The bg-colored stroke creates the gap that separates overlapping avatars.
        .overlay(ring ? Circle().stroke(DS.bg, lineWidth: 2.5) : nil)
    }
}
