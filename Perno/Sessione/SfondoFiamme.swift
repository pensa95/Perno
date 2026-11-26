import SwiftUI

// MARK: - Sfondo del set in corso (UI v6, T15) — in prova
//
// Durante il set in corso il fondo diventa più caldo (#EFEBE8, scuro #1A1716) con fiamme sfumate che salgono
// piano dietro le piastre (tavole 4, 16 e Tema scuro). Dock e piastre non cambiano. Ferme con «Riduci movimento».
//
// ROLLBACK: per toglierle basta mettere `attive` a `false` qui sotto: la sessione torna al fondo lamiera di
// sempre. Per toglierle del tutto si cancella questo file e si rimette `Color.lamiera` in `SessioneView`
// (unica riga che usa `SfondoSessione`).
enum Fiamme {
    static let attive = true
}

/// Fondo della schermata della sessione: lamiera, oppure (set in corso, con `Fiamme.attive`) il fondo caldo
/// con le fiamme.
struct SfondoSessione: View {
    /// Fase «set in corso».
    let setInCorso: Bool

    var body: some View {
        ZStack {
            Color.lamiera
            if Fiamme.attive && setInCorso {
                Color.fondoSetInCorso
                    .overlay(alignment: .bottom) { FiammeAnimate() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: setInCorso)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private extension Color {
    /// Fondo caldo del set in corso: #EFEBE8 nel chiaro, #1A1716 nello scuro.
    static let fondoSetInCorso = Color.token(light: 0xEFEBE8, dark: 0x1A1716)
}

/// Due strati di macchie radiali arancio, rosse e ambra, sfocate, che si allungano verso l'alto e oscillano
/// piano (4,5 s e 3,2 s, avanti e indietro). Sono alte 560 e partono 180 pt sopra il bordo in basso, cioè
/// dietro il dock, larghe il 140% dello schermo.
private struct FiammeAnimate: View {
    @Environment(\.accessibilityReduceMotion) private var menoMovimento
    @State private var su = false

    var body: some View {
        GeometryReader { spazio in
            let larghezza = spazio.size.width * 1.4
            ZStack(alignment: .bottom) {
                strato([
                    Macchia(colore: Color(red: 234 / 255, green: 88 / 255, blue: 12 / 255).opacity(0.55),
                            x: 0.25, raggi: CGSize(width: 0.45, height: 0.55), fine: 0.70),
                    Macchia(colore: Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255).opacity(0.45),
                            x: 0.75, raggi: CGSize(width: 0.40, height: 0.50), fine: 0.70),
                    Macchia(colore: Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255).opacity(0.5),
                            x: 0.50, raggi: CGSize(width: 0.35, height: 0.60), fine: 0.72),
                ], larghezza: larghezza, durata: 4.5, ritardo: 0)
                strato([
                    Macchia(colore: Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255).opacity(0.55),
                            x: 0.40, raggi: CGSize(width: 0.30, height: 0.45), fine: 0.70),
                    Macchia(colore: Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255).opacity(0.4),
                            x: 0.65, raggi: CGSize(width: 0.30, height: 0.40), fine: 0.70),
                ], larghezza: larghezza, durata: 3.2, ritardo: 1.4)
                .opacity(0.7)
            }
            .frame(width: larghezza, height: 560)
            .position(x: spazio.size.width / 2, y: spazio.size.height - 180 - 280)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !menoMovimento else { return }
            su = true
        }
    }

    /// Uno strato: le macchie disegnate una volta e sfocate, poi solo allungate e spostate (niente ridisegni).
    private func strato(_ macchie: [Macchia], larghezza: CGFloat, durata: Double, ritardo: Double) -> some View {
        Canvas { contesto, misura in
            for macchia in macchie {
                let rx = macchia.raggi.width * misura.width
                let ry = macchia.raggi.height * misura.height
                var copia = contesto
                // Gradiente circolare schiacciato in orizzontale: un'ellisse come il radial-gradient della tavola.
                copia.translateBy(x: macchia.x * misura.width, y: misura.height)
                copia.scaleBy(x: rx / ry, y: 1)
                let cerchio = CGRect(x: -ry, y: -ry, width: ry * 2, height: ry * 2)
                copia.fill(Path(ellipseIn: cerchio),
                           with: .radialGradient(Gradient(colors: [macchia.colore, macchia.colore.opacity(0)]),
                                                 center: .zero, startRadius: 0, endRadius: ry * macchia.fine))
            }
        }
        .blur(radius: 18)
        .drawingGroup()
        .scaleEffect(x: 1, y: menoMovimento ? 0.9 : (su ? 1 : 0.82), anchor: .bottom)
        .offset(x: menoMovimento ? 0 : (su ? 0.03 : -0.02) * larghezza)
        .animation(menoMovimento ? nil
                   : .easeInOut(duration: durata).repeatForever(autoreverses: true).delay(ritardo),
                   value: su)
    }

    private struct Macchia {
        let colore: Color
        /// Centro in orizzontale (0…1), sul bordo in basso dello strato.
        let x: CGFloat
        /// Raggi in frazione della larghezza e dell'altezza dello strato.
        let raggi: CGSize
        /// Dove il colore è già trasparente, in frazione del raggio.
        let fine: CGFloat
    }
}
