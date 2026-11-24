import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit
import PernoCore

/// Live Activity della sessione: card sul blocco schermo e Dynamic Island
/// (canvas «App palestra — Live Activity e Dynamic Island», tavole LA1–LA5 e DI).
struct SessioneLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AttivitaSessioneAttributes.self) { contesto in
            let colori = ColoriFase(contesto.state.tone)
            CardBloccoSchermo(stato: contesto.state, colori: colori)
                .activityBackgroundTint(colori.fondo)
                .activitySystemActionForegroundColor(colori.testo)
                .widgetURL(IndirizziPerno.sessione)
        } dynamicIsland: { contesto in
            let stato = contesto.state
            let colori = ColoriFase(stato.tone)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            PuntoPerno(dimensione: 14)
                            Text(stato.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(colori.tintaIsola)
                                .lineLimit(1)
                        }
                        TempoSessione(stato: stato, dimensione: 44)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(stato.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                        RigaSet(stato: stato, tenue: Color.piastraTenue)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.trailing, 6)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        if stato.showsProgress, let fine = stato.timerEnd {
                            BarraRecupero(inizio: stato.timerStart, fine: fine,
                                          colore: colori.tintaIsola, traccia: Color.white.opacity(0.2))
                        }
                        Pulsanti(stato: stato,
                                 principale: (colori.principaleIsola, colori.suPrincipaleIsola),
                                 secondario: (Color.white.opacity(0.16), Color.white))
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
                }
            } compactLeading: {
                PuntoPerno(dimensione: 20)
            } compactTrailing: {
                TempoSessione(stato: stato, dimensione: 20, grande: false)
                    .foregroundStyle(colori.tintaIsola)
                    .frame(maxWidth: 56, alignment: .trailing)
            } minimal: {
                ZStack {
                    if stato.showsProgress, let fine = stato.timerEnd, stato.timerPrefix == nil {
                        ProgressView(timerInterval: stato.timerStart...fine, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .progressViewStyle(.circular)
                        .tint(colori.tintaIsola)
                    }
                    PuntoPerno(dimensione: 14)
                }
            }
            .widgetURL(IndirizziPerno.sessione)
            .keylineTint(colori.tintaIsola)
        }
    }
}

// MARK: - Card sul blocco schermo

struct CardBloccoSchermo: View {
    let stato: LiveActivityState
    let colori: ColoriFase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(stato.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(colori.tenue)
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    PuntoPerno(dimensione: 14)
                    Text(stato.routine)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(colori.tenue)
                        .lineLimit(1)
                }
            }
            HStack(alignment: .bottom, spacing: 12) {
                TempoSessione(stato: stato, dimensione: stato.bigTimer ? 64 : 48)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(stato.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    RigaSet(stato: stato, tenue: colori.tenue)
                }
            }
            .padding(.top, 2)
            if stato.showsProgress, let fine = stato.timerEnd {
                BarraRecupero(inizio: stato.timerStart, fine: fine, colore: colori.barra, traccia: colori.traccia)
                    .padding(.top, 10)
            }
            if stato.primary != nil {
                Pulsanti(stato: stato,
                         principale: (colori.principale, colori.suPrincipale),
                         secondario: (colori.secondario, colori.suSecondario))
                    .padding(.top, 12)
            }
        }
        .foregroundStyle(colori.testo)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }
}

// MARK: - Pezzi

/// Il perno: disco giallo con il foro scuro (come sulla piastra di adesso).
struct PuntoPerno: View {
    let dimensione: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.perno)
            Circle().fill(Color.suPerno).frame(width: dimensione * 0.3, height: dimensione * 0.3)
        }
        .frame(width: dimensione, height: dimensione)
        .accessibilityHidden(true)
    }
}

/// Tempo che scorre da solo: cronometro da `timerStart`, oppure conto alla rovescia fino a
/// `timerEnd` (che dopo lo zero continua a contare il tempo in più).
struct TempoSessione: View {
    let stato: LiveActivityState
    let dimensione: CGFloat
    var grande = true

    var body: some View {
        HStack(spacing: 0) {
            if let prefisso = stato.timerPrefix {
                Text(prefisso)
            }
            if let fine = stato.timerEnd {
                Text(fine, style: .timer)
            } else {
                Text(timerInterval: stato.timerStart...Date.distantFuture, countsDown: false)
            }
        }
        .font(.piastra(dimensione))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: grande ? dimensione * 2.6 : .infinity, alignment: grande ? .leading : .trailing)
    }
}

/// «Set 2  62,5 × 10».
struct RigaSet: View {
    let stato: LiveActivityState
    let tenue: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(stato.setLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tenue)
            if let valore = stato.setValue {
                Text(valore)
                    .font(.piastra(24))
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
    }
}

struct BarraRecupero: View {
    let inizio: Date
    let fine: Date
    let colore: Color
    let traccia: Color

    var body: some View {
        ProgressView(timerInterval: inizio...fine, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(colore)
        .background(traccia, in: Capsule())
        .accessibilityHidden(true)
    }
}

/// Pulsante principale a sinistra, secondario a destra (come nel dock). `open` apre l'app.
struct Pulsanti: View {
    let stato: LiveActivityState
    let principale: (fondo: Color, testo: Color)
    let secondario: (fondo: Color, testo: Color)

    var body: some View {
        HStack(spacing: 8) {
            if let primo = stato.primary {
                pulsante(primo, fondo: principale.fondo, testo: principale.testo, largo: true)
            }
            if let secondo = stato.secondary {
                pulsante(secondo, fondo: secondario.fondo, testo: secondario.testo, largo: false)
            }
        }
    }

    @ViewBuilder
    private func pulsante(_ voce: LiveActivityButton, fondo: Color, testo: Color, largo: Bool) -> some View {
        let etichetta = Text(voce.title)
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(testo)
            .padding(.horizontal, 18)
            .frame(maxWidth: largo ? .infinity : nil, minHeight: 44)
            .background(fondo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        if voce.action == .open {
            Link(destination: IndirizziPerno.sessione) { etichetta }
        } else {
            Button(intent: AzioneSessioneIntent(voce.action)) { etichetta }
                .buttonStyle(.plain)
        }
    }
}

// MARK: - Colori per fase (Design System «Pacco pesi»)

struct ColoriFase {
    let fondo: Color
    let testo: Color
    let tenue: Color
    let principale: Color
    let suPrincipale: Color
    let secondario: Color
    let suSecondario: Color
    let barra: Color
    let traccia: Color
    /// Tempo e etichetta su nero (Dynamic Island).
    let tintaIsola: Color
    let principaleIsola: Color
    let suPrincipaleIsola: Color

    private static let bianco = Color(UIColor(hex: 0xFFFFFF))
    private static let velo = Color.white.opacity(0.16)

    init(_ tono: LiveActivityTone) {
        switch tono {
        case .warmUp:
            fondo = .riscaldamento; testo = Self.bianco; tenue = .riscaldamentoTenue
            principale = Self.bianco; suPrincipale = .suPerno; secondario = Self.velo; suSecondario = Self.bianco
            barra = Self.bianco; traccia = Color.white.opacity(0.28)
            tintaIsola = Color(UIColor(hex: 0xFB8A4C)); principaleIsola = .riscaldamento; suPrincipaleIsola = Self.bianco
        case .changeover:
            fondo = .piastra; testo = .piastraTesto; tenue = .piastraTenue
            principale = Self.bianco; suPrincipale = .suPerno; secondario = Self.velo; suSecondario = Self.bianco
            barra = Self.bianco; traccia = Color.white.opacity(0.24)
            tintaIsola = Color(UIColor(hex: 0xA9B3BA)); principaleIsola = Self.bianco; suPrincipaleIsola = .suPerno
        case .inSet:
            fondo = .foglio; testo = .inchiostro; tenue = .inchiostroTenue
            principale = .inchiostro; suPrincipale = .suInchiostro; secondario = .lamiera; suSecondario = .inchiostro
            barra = .inchiostro; traccia = .lamiera
            tintaIsola = Self.bianco; principaleIsola = Self.bianco; suPrincipaleIsola = .suPerno
        case .rest:
            fondo = .recupero; testo = Self.bianco; tenue = .recuperoTenue
            principale = Self.bianco; suPrincipale = .suPerno; secondario = Self.velo; suSecondario = Self.bianco
            barra = Self.bianco; traccia = Color.white.opacity(0.28)
            tintaIsola = Color(UIColor(hex: 0x7FA6F0)); principaleIsola = .recupero; suPrincipaleIsola = Self.bianco
        case .finished:
            fondo = .foglio; testo = .inchiostro; tenue = .inchiostroTenue
            principale = .perno; suPrincipale = .suPerno; secondario = .lamiera; suSecondario = .inchiostro
            barra = .inchiostro; traccia = .lamiera
            tintaIsola = .perno; principaleIsola = .perno; suPrincipaleIsola = .suPerno
        }
    }
}
