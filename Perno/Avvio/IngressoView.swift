import SwiftUI
import SwiftData

/// Marchio v1.2 senza fondo, 168 × 100 pt: stesse misure e colori dell'immagine della launch screen
/// (`LaunchMarchio` nel catalogo), così il primo fotogramma dell'animazione è identico a quello di iOS.
/// Il centro della vista è il centro del perno. Misure sulla griglia 672 × 400 dell'identity, scala 1/4.
struct MarchioIngresso: View {
    static let larghezza: CGFloat = 168
    static let altezza: CGFloat = 100
    static let raggioPerno: CGFloat = 24

    /// Aspetto dell'iPhone (non quello scelto nell'app: la launch screen non lo conosce).
    let scuro: Bool

    private var colorBarre: Color { Color(UIColor(hex: scuro ? 0xA9B3BA : 0x2A3136)) }

    private func barra(x: CGFloat, y: CGFloat, larghezza: CGFloat, altezza: CGFloat) -> some View {
        Capsule()
            .fill(colorBarre)
            .frame(width: larghezza, height: altezza)
            .position(x: x + larghezza / 2, y: y + altezza / 2)
    }

    var body: some View {
        ZStack {
            barra(x: 0, y: 20, larghezza: 20, altezza: 60)
            barra(x: 27, y: 0, larghezza: 24, altezza: 100)
            barra(x: 117, y: 0, larghezza: 24, altezza: 100)
            barra(x: 148, y: 20, larghezza: 20, altezza: 60)
            Circle()
                .fill(Color.perno)
                .frame(width: Self.raggioPerno * 2, height: Self.raggioPerno * 2)
                .position(x: Self.larghezza / 2, y: Self.altezza / 2)
        }
        .frame(width: Self.larghezza, height: Self.altezza)
    }
}

/// Animazione d'ingresso «Dentro il perno» (C2, scelta il 27/11): parte dal fotogramma della launch
/// screen (marchio sulla lamiera), uno zoom che accelera entra nel perno finché lo schermo è tutto
/// giallo, poi il giallo sfuma mentre la Home entra da più vicino. 0,77 s in tutto.
///
/// Il giallo a tutto schermo è un fotogramma di passaggio (eccezione alla regola «mai fondo giallo»,
/// `identity-v1.md`), mai un fondo fermo.
///
/// Casi senza animazione: con una sessione aperta o da rivedere (si va dritti alla Home, dove c'è la card
/// «Riprendi») dissolvenza di 0,15 s; con «Riduci movimento» dissolvenza di 0,25 s.
///
/// La Home vera sta sotto: parte nascosta (`homeOpacita` 0, `homeScala` 1,14) e questa vista la porta a 1.
struct IngressoView: View {
    /// Aspetto dell'iPhone, per il fondo e le barre del marchio.
    let scuro: Bool
    @Binding var homeScala: CGFloat
    @Binding var homeOpacita: Double
    /// Chiamata a fine animazione: la vista si toglie.
    let fine: () -> Void

    @Environment(\.accessibilityReduceMotion) private var menoMovimento
    @Query private var sessioni: [WorkoutSession]

    @State private var scalaMarchio: CGFloat = 1
    @State private var opacitaLaunch: Double = 1
    @State private var partito = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(UIColor(hex: scuro ? 0x14181B : 0xECEFF1))
                MarchioIngresso(scuro: scuro)
                    .scaleEffect(scalaMarchio, anchor: .center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .compositingGroup()
            .opacity(opacitaLaunch)
            .onAppear { avvia(schermo: geo.size) }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func avvia(schermo: CGSize) {
        guard !partito else { return }
        partito = true

        // Sessione aperta (interrotta) o chiusa da sola e da rivedere: niente animazione.
        let daRivedere = sessioni.contains { $0.endedAt == nil || ($0.closedAutomatically && !$0.isSaved) }
        if daRivedere || menoMovimento {
            // La Home è già pronta sotto la launch screen (non si vede: la launch screen è opaca).
            homeScala = 1
            homeOpacita = 1
            withAnimation(.easeInOut(duration: daRivedere ? 0.15 : 0.25)) {
                opacitaLaunch = 0
            } completion: {
                fine()
            }
            return
        }

        // Il perno deve coprire tutto lo schermo: il suo raggio arriva alla metà della diagonale.
        let copre = hypot(schermo.width, schermo.height) / 2 / MarchioIngresso.raggioPerno * 1.05
        withAnimation(.timingCurve(0.75, 0, 0.9, 0.25, duration: 0.44)) {
            scalaMarchio = copre
        } completion: {
            esci()
        }
    }

    /// Il perno copre lo schermo: il giallo sfuma, la Home entra da scala 1,14 a 1.
    private func esci() {
        withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.26)) {
            opacitaLaunch = 0
        } completion: {
            fine()
        }
        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.32).delay(0.01)) {
            homeScala = 1
            homeOpacita = 1
        }
    }
}
