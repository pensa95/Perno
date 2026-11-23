import SwiftUI

/// Marchio v1.1: asta, tre piastre e il perno sulla piastra centrale, con taglio vero intorno al perno.
/// Coordinate sulla griglia 120 dell'identity.
struct PernoMark: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 120

            func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * unit, y: y * unit, width: width * unit, height: height * unit),
                     cornerRadius: radius * unit)
            }

            func circle(_ centerX: CGFloat, _ centerY: CGFloat, _ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (centerX - radius) * unit, y: (centerY - radius) * unit,
                                       width: radius * 2 * unit, height: radius * 2 * unit))
            }

            // Asta e piastre.
            context.fill(box(55, 22, 10, 20, 2), with: .color(.piastra))
            for top: CGFloat in [44, 66, 88] {
                context.fill(box(26, top, 68, 16, 4), with: .color(.piastra))
            }

            // Taglio di 4 unità intorno al perno: trasparente, non dipinto col colore del fondo.
            context.blendMode = .clear
            context.fill(box(66, 67, 28, 14, 0), with: .color(.black))
            context.fill(circle(94, 74, 18), with: .color(.black))
            context.blendMode = .normal

            // Perno: stelo e testa.
            context.fill(box(70, 71, 24, 6, 1), with: .color(.perno))
            context.fill(circle(94, 74, 14), with: .color(.perno))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Marchio Perno")
    }
}

#Preview {
    PernoMark()
        .frame(width: 136, height: 136)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
}
