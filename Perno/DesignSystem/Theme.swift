import SwiftUI
import UIKit

// Token del Design System «Pacco pesi» (chiaro / scuro).
extension Color {
    static let lamiera = Color.token(light: 0xECEFF1, dark: 0x14181B)
    static let foglio = Color.token(light: 0xFFFFFF, dark: 0x20262A)
    static let inchiostro = Color.token(light: 0x1C2226, dark: 0xEEF1F3)
    static let inchiostroTenue = Color.token(light: 0x566069, dark: 0x9AA5AD)
    static let linea = Color.token(light: 0xC9D0D5, dark: 0x2E353A)
    static let piastra = Color.token(light: 0x2A3136, dark: 0x353E45)
    static let piastraTesto = Color.token(light: 0xF2F4F5, dark: 0xF2F4F5)
    static let piastraTenue = Color.token(light: 0xA9B3BA, dark: 0xB4BEC5)
    static let piastraFatta = Color.token(light: 0xDCE1E4, dark: 0x252B30)
    static let perno = Color.token(light: 0xF5B700, dark: 0xF5B700)
    static let suPerno = Color.token(light: 0x1C2226, dark: 0x1C2226)
    static let recupero = Color.token(light: 0x2457B8, dark: 0x2457B8)
    static let recuperoTenue = Color.token(light: 0xC9DAF7, dark: 0xC9DAF7)
    static let riscaldamento = Color.token(light: 0xC2410C, dark: 0xC2410C)
    static let riscaldamentoTenue = Color.token(light: 0xFFE4D6, dark: 0xFFE4D6)
    static let errore = Color.token(light: 0xB3261E, dark: 0xF2867C)

    static func token(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// Numeri e titoli. Barlow Condensed quando sarà inclusa; per ora il system font condensed.
    static func piastra(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).width(.condensed)
    }
}
