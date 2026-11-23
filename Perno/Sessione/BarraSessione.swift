import SwiftUI
import PernoCore

/// Barra della sessione ridotta, sulle sezioni diverse dalla Home: colore della fase (come il dock),
/// nome della scheda, fase e tempo. Il tocco riapre la schermata della sessione.
struct BarraSessione: View {
    let sessione: SessioneInCorso
    let apri: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { contesto in
            let fase = descrizione(ora: contesto.date)
            Button(action: apri) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(fase.colore)
                        .frame(width: 12, height: 12)
                        .overlay { Circle().strokeBorder(Color.inchiostro.opacity(0.12), lineWidth: 1) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(sessione.sessione.titolo)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inchiostro)
                            .lineLimit(1)
                        Text(fase.etichetta)
                            .font(.footnote)
                            .foregroundStyle(Color.inchiostroTenue)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(fase.tempo)
                        .font(.piastra(22))
                        .monospacedDigit()
                        .foregroundStyle(Color.inchiostro)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.inchiostro.opacity(0.12), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sessione in corso, \(sessione.sessione.titolo), \(fase.etichetta) \(fase.tempo)")
            .accessibilityHint("Torna alla sessione")
        }
    }

    private func descrizione(ora: Date) -> (etichetta: String, tempo: String, colore: Color) {
        let numero = sessione.numeroSetCorrente
        let tipo = sessione.setCorrente?.kind ?? .work
        switch sessione.fase {
        case let .warmUp(dal):
            return ("Riscaldamento in corso", SessionText.clock(ora.timeIntervalSince(dal)), .riscaldamento)
        case let .changeover(dal):
            return ("Cambio esercizio", SessionText.clock(ora.timeIntervalSince(dal)), .piastra)
        case let .countdown(_, inizio, _):
            return (SessionText.countdownTitle(tipo, numero), SessionText.clock(ora.timeIntervalSince(inizio)), .piastra)
        case let .inSet(dal):
            return (SessionText.inProgress(tipo, numero), SessionText.clock(ora.timeIntervalSince(dal)), .foglio)
        case let .rest(dal):
            return ("Recupero", RestTimer.display(mode: sessione.modoRecupero, elapsed: ora.timeIntervalSince(dal),
                                                  duration: sessione.durataRecupero), .recupero)
        case .finished:
            return ("Sessione finita", SessionText.clock(ora.timeIntervalSince(sessione.sessione.startedAt)), .piastra)
        }
    }
}
