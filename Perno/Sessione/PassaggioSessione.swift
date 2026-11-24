import SwiftUI
import PernoCore

/// Cornici (in coordinate della finestra) della card «Sessione in corso» in Home e della barra della
/// sessione ridotta. Servono solo all'animazione tra le due, quindi stanno in un oggetto non osservato:
/// cambiarle (per esempio scorrendo la Home) non ridisegna le viste.
final class CorniciSessione {
    var card: CGRect?
    var barra: CGRect?
}

/// Passaggio animato tra la card della Home e la barra della sessione ridotta.
struct PassaggioSessione: Equatable {
    var da: CGRect
    var a: CGRect
    /// `true` dalla card alla barra (si lascia la Home), `false` dalla barra alla card.
    var versoBarra: Bool
    var arrivato = false

    /// Durata dell'animazione (molla breve, come le transizioni di sistema).
    static let durata: Double = 0.35
}

/// Il «fantasma» che si trasforma: parte con forma, colore e intestazione della card (raggio 28, colore
/// della fase) e arriva con quelli della barra (raggio 16, foglio, contenuto della barra), o al contrario.
struct FantasmaSessione: View {
    let sessione: SessioneInCorso
    let passaggio: PassaggioSessione

    var body: some View {
        GeometryReader { geo in
            let origine = geo.frame(in: .global).origin
            let cornice = (passaggio.arrivato ? passaggio.a : passaggio.da)
                .offsetBy(dx: -origine.x, dy: -origine.y)
            // Aspetto di barra all'arrivo verso la barra e alla partenza dalla barra.
            let barra = passaggio.arrivato == passaggio.versoBarra
            let fase = FaseCard(sessione)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: barra ? 16 : 28, style: .continuous)
                    .fill(barra ? Color.foglio : fase.sfondo)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fase.etichetta)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(fase.tenue)
                        .lineLimit(1)
                    Text(sessione.sessione.titolo)
                        .font(.piastra(48))
                        .foregroundStyle(fase.testo)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .opacity(barra ? 0 : 1)
                BarraSessione(sessione: sessione) {}
                    .frame(maxHeight: .infinity)
                    .opacity(barra ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: barra ? 16 : 28, style: .continuous))
            .shadow(color: Color.ombra.opacity(barra ? 0.12 : 0), radius: 12, x: 0, y: 4)
            .frame(width: cornice.width, height: cornice.height)
            .position(x: cornice.midX, y: cornice.midY)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Riporta la cornice della vista in coordinate della finestra, quando compare e quando cambia.
    func misuraCornice(_ salva: @escaping (CGRect) -> Void) -> some View {
        background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { salva(geo.frame(in: .global)) }
                    .onChange(of: geo.frame(in: .global)) { _, cornice in salva(cornice) }
            }
        }
    }
}
