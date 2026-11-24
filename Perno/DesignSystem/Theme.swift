import SwiftUI
import UIKit

// Token del Design System «Pacco pesi» (chiaro / scuro).
extension Color {
    static let lamiera = Color.token(light: 0xECEFF1, dark: 0x14181B)
    static let foglio = Color.token(light: 0xFFFFFF, dark: 0x20262A)
    static let inchiostro = Color.token(light: 0x1C2226, dark: 0xEEF1F3)
    static let inchiostroTenue = Color.token(light: 0x566069, dark: 0x9AA5AD,
                                             lightContrasto: 0x3F474E, darkContrasto: 0xB9C2C8)
    static let linea = Color.token(light: 0xC9D0D5, dark: 0x2E353A,
                                   lightContrasto: 0x9AA4AB, darkContrasto: 0x4A545B)
    static let piastra = Color.token(light: 0x2A3136, dark: 0x353E45)
    static let piastraTesto = Color.token(light: 0xF2F4F5, dark: 0xF2F4F5)
    static let piastraTenue = Color.token(light: 0xA9B3BA, dark: 0xB4BEC5)
    static let piastraFatta = Color.token(light: 0xDCE1E4, dark: 0x252B30)
    static let perno = Color.token(light: 0xF5B700, dark: 0xF5B700)
    static let suPerno = Color.token(light: 0x1C2226, dark: 0x1C2226)
    static let recupero = Color.token(light: 0x2457B8, dark: 0x2457B8)
    static let recuperoTenue = Color.token(light: 0xC9DAF7, dark: 0xC9DAF7)
    static let riscaldamento = Color.token(light: 0xC2410C, dark: 0xC2410C)
    /// Testi tenui sul fondo arancio: #FFF1EA arriva a 4,7:1 (prima #FFE4D6, 4,3:1).
    static let riscaldamentoTenue = Color.token(light: 0xFFF1EA, dark: 0xFFF1EA)
    static let errore = Color.token(light: 0xB3261E, dark: 0xF2867C)

    // Derivati per il tema scuro (tavole «Home, scuro», «Set in corso, scuro», «Recupero, scuro»).
    /// Testo e icone sopra un fondo inchiostro (pulsante «Set N fatto», scelte piene).
    static let suInchiostro = Color.token(light: 0xFFFFFF, dark: 0x14181B)
    /// Ombre: inchiostro nel chiaro, nero nello scuro (un'ombra chiara sembrerebbe un alone).
    static let ombra = Color.token(light: 0x1C2226, dark: 0x000000)
    /// Calendario: bordo tratteggiato di oggi, dei giorni in programma, dei giorni saltati, puntino del riposo.
    static let bordoOggi = Color.token(light: 0x2A3136, dark: 0xEEF1F3)
    /// Almeno 3:1 sulla lamiera (prima 1,9:1 nel chiaro e 3,0:1 nello scuro).
    static let bordoProgramma = Color.token(light: 0x7D878E, dark: 0x6E7880,
                                            lightContrasto: 0x5F6970, darkContrasto: 0x8A949B)
    static let bordoSaltato = Color.token(light: 0x2A3136, dark: 0x9AA5AD)
    /// Voce scelta del selettore a segmenti: più chiara del fondo (piastra fatta) in tutti e due i temi.
    static let segmentoScelto = Color.token(light: 0xFFFFFF, dark: 0x353E45)
    static let puntoRiposo = Color.token(light: 0x7D878E, dark: 0x9AA5AD,
                                         lightContrasto: 0x5F6970, darkContrasto: 0xB9C2C8)
    /// Icone tenui su foglio o lamiera (maniglia «=» per spostare): almeno 3:1.
    static let iconaTenue = Color.token(light: 0x7D878E, dark: 0x9AA5AD,
                                        lightContrasto: 0x5F6970, darkContrasto: 0xB9C2C8)

    /// Colore chiaro / scuro, con varianti più contrastate per «Aumenta contrasto» (se date).
    static func token(light: UInt32, dark: UInt32,
                      lightContrasto: UInt32? = nil, darkContrasto: UInt32? = nil) -> Color {
        Color(UIColor { traits in
            let scuro = traits.userInterfaceStyle == .dark
            if traits.accessibilityContrast == .high {
                return UIColor(hex: scuro ? (darkContrasto ?? dark) : (lightContrasto ?? light))
            }
            return UIColor(hex: scuro ? dark : light)
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
    /// Numeri e titoli in Barlow Condensed (OFL, file in `Perno/Resources/Fonts`, registrati con
    /// `UIAppFonts`). Semibold di default, come nelle tavole; `.medium` per i pesi 500.
    static func piastra(_ size: CGFloat, peso: Font.Weight = .semibold) -> Font {
        .custom(peso == .medium ? "BarlowCondensed-Medium" : "BarlowCondensed-SemiBold", fixedSize: size)
    }
}
