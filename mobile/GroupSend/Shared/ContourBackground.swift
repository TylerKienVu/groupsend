import SwiftUI

// Topographic contour lines — concentric ellipses used as decorative texture
// on the phone entry, empty state, check-in, and invite screens.
struct ContourBackground: View {
    var opacity: Double = 0.08
    var color: Color = Color(hex: "#E8FF5C")

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<14 {
                let r = 40.0 + Double(i) * 28.0
                let cx = size.width / 2
                // cy at 53% height mirrors the SVG viewBox (cy=320 in a 600-tall box)
                let cy = size.height * 0.53
                let rect = CGRect(x: cx - r, y: cy - r * 0.82, width: r * 2, height: r * 0.82 * 2)
                let path = Path(ellipseIn: rect)
                ctx.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
