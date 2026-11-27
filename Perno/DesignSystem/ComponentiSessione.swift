import SwiftUI
import PernoCore

// Componenti propri della schermata della sessione (UI v3): piastra del set e dock.

// MARK: - Perno condiviso

private struct SpazioPernoKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Spazio in cui il perno passa da una piastra all'altra (C5): lo imposta la schermata della sessione.
    var spazioPerno: Namespace.ID? {
        get { self[SpazioPernoKey.self] }
        set { self[SpazioPernoKey.self] = newValue }
    }
}

extension View {
    /// Il perno della piastra di adesso e quello della piastrina del recupero sono lo stesso perno: cambiando
    /// piastra scivola dall'una all'altra (senza spazio, per esempio fuori dalla sessione, resta com'è).
    @ViewBuilder
    func pernoCondiviso(_ spazio: Namespace.ID?) -> some View {
        if let spazio {
            matchedGeometryEffect(id: "perno", in: spazio)
        } else {
            self
        }
    }
}

// MARK: - Piastra del set

/// Piastra di un set: adesso = grafite alta 88 pt con il perno; fatta = fondo chiaro pieno con la spunta;
/// da fare = solo bordo, numeri tenui e «obiettivo».
struct PiastraSet: View {
    enum Stato {
        /// `evidenza` è il dato in chiaro a destra («+2,5 kg»), `nota` quello tenue («prima 60 × 12»).
        case adesso(etichetta: String, evidenza: String?, nota: String?)
        case fatta(nota: String?)
        case daFare
    }

    let nome: String
    let valore: String
    let stato: Stato
    /// Avvicinamento: tinta calda (UI v6) al posto della grafite.
    var calda = false
    /// Piastra fatta oltre l'obiettivo: badge «+3» accanto al valore (UI v6).
    var badge: String? = nil
    /// Piastra fatta: faccina piccola a destra (UI v6).
    var faccina: Feeling? = nil
    /// Piastra di lavoro fatta senza faccina: un posto vuoto tratteggiato dice che si può scegliere (D3).
    var faccinaVuota = false
    /// Nota della piastra da fare: «obiettivo», o «prossimo» durante il recupero.
    var notaDaFare = "obiettivo"
    @Environment(\.spazioPerno) private var spazioPerno

    var body: some View {
        Group {
            switch stato {
            case let .adesso(etichetta, evidenza, nota):
                adesso(etichetta: etichetta, evidenza: evidenza, nota: nota)
            case let .fatta(nota):
                riga(fatta: true, nota: nota)
            case .daFare:
                riga(fatta: false, nota: notaDaFare)
            }
        }
        // Piastre ad altezza fissa (88 e 44 pt, come nelle tavole): il testo cresce fino a xxxLarge.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func adesso(etichetta: String, evidenza: String?, nota: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.perno).frame(width: 26, height: 26)
                Circle().fill(Color.suPerno).frame(width: 8, height: 8)
            }
            .pernoCondiviso(spazioPerno)
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(etichetta)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(calda ? Color.avvicinamentoTenue : Color.piastraTenue)
                Text(valore)
                    .font(.piastra(48))
                    .monospacedDigit()
                    .foregroundStyle(Color.piastraTesto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .numeriCheRuotano(valore)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if let evidenza {
                    Text(evidenza).fontWeight(.semibold).foregroundStyle(Color.piastraTesto)
                }
                if let nota {
                    Text(nota).foregroundStyle(calda ? Color.avvicinamentoTenue : Color.piastraTenue)
                }
            }
            .font(.footnote.weight(.medium))
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88)
        .background(calda ? Color.avvicinamentoAdesso : Color.piastra,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nome), adesso. \(valore)")
    }

    private func riga(fatta: Bool, nota: String?) -> some View {
        HStack(spacing: 8) {
            Group {
                if fatta {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(calda ? Color.avvicinamentoFatto : Color.piastraFatta)
                        .frame(width: 20, height: 20)
                        .background(Color.inchiostro, in: Circle())
                } else {
                    Circle()
                        .strokeBorder(calda ? Color.riscaldamento : Color.inchiostroTenue, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 28, alignment: .leading)
            Text(nome)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(fatta ? Color.inchiostro : Color.inchiostroTenue)
                .frame(minWidth: 52, alignment: .leading)
                .lineLimit(1)
                .fixedSize()
            HStack(spacing: 8) {
                Text(valore)
                    .font(.piastra(26, peso: fatta ? .semibold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(fatta ? Color.inchiostro : Color.inchiostroTenue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .numeriCheRuotano(valore)
                if fatta, let badge {
                    Text(badge)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.suInchiostro)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(Color.inchiostro, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .fixedSize()
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if fatta, let faccina {
                    Faccina(tipo: faccina, dimensione: 20, colore: .inchiostroTenue)
                } else if fatta, faccinaVuota {
                    Circle()
                        .strokeBorder(Color.inchiostroTenue.opacity(0.45),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 3]))
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }
                if let nota {
                    Text(nota)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        .background {
            if fatta {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(calda ? Color.avvicinamentoFatto : Color.piastraFatta)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(calda ? Color.riscaldamento.opacity(0.38) : Color.inchiostro.opacity(0.22),
                                  lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fatta
            ? ([("\(nome) fatto, \(valore)"), badge.map { "\($0) sull'obiettivo" }, faccina?.word]
                .compactMap { $0 }.joined(separator: ", "))
            : "\(nome) da fare, \(notaDaFare) \(valore)")
    }
}

/// Recupero in corso come piastrina tra il set fatto e il set dopo (UI v6, tavole 5, 5b, 5c): blu, alta 52,
/// perno, «Recupero» con il tempo del dock, a destra «di solito 2:10» o «fissato a 2:00».
struct PiastrinaRecupero: View {
    let tempo: String
    let nota: String?
    @Environment(\.spazioPerno) private var spazioPerno

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.perno).frame(width: 26, height: 26)
                Circle().fill(Color.suPerno).frame(width: 8, height: 8)
            }
            .pernoCondiviso(spazioPerno)
            .frame(width: 28)
            HStack(spacing: 10) {
                Text("Recupero")
                    .font(.subheadline.weight(.semibold))
                Text(tempo)
                    .font(.piastra(30))
                    .monospacedDigit()
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            if let nota {
                Text(nota)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.recuperoTenue)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
        .background(Color.recupero, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recupero in corso, \(tempo)")
    }
}

/// Recupero finito tra due set: riga sottile «recupero 2:12» con l'orologio (tempo misurato).
struct RigaRecupero: View {
    let testo: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .semibold))
            Text(testo)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(Color.inchiostroTenue)
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - Dock

/// Dock fisso in basso, alto 224 pt: stato e timer a 64 pt a sinistra, posto secondario a destra
/// (non fa mai avanzare), 24 pt fissi e il pulsante principale da 64 pt.
struct DockSessione: View {
    struct Pulsante {
        var titolo: String
        var dettaglio: String? = nil
        var icona: String? = nil
        var sfondo: Color = .white
        var testo: Color = .suPerno
        let azione: () -> Void
    }

    struct Secondario {
        var titolo: String
        let azione: () -> Void
    }

    let sfondo: Color
    let coloreEtichetta: Color
    let coloreTesto: Color
    let etichetta: String
    let tempo: String
    var secondario: Secondario? = nil
    var principale: Pulsante? = nil
    var bordoSopra = false
    /// Tocco sul tempo (recupero: cronometro ↔ conto alla rovescia), con l'icona accanto.
    var azioneTempo: (() -> Void)? = nil
    /// Set a tempo (UI v5): «di 0:45» a destra del tempo e barra di avanzamento (0…1) sotto.
    var notaTempo: String? = nil
    var avanzamento: Double? = nil
    /// Set a tempo: inizio e durata in secondi. La barra scorre fluida (a ogni fotogramma, D10) dal tempo
    /// trascorso, invece di avanzare a ogni aggiornamento del dock. Ha la precedenza su `avanzamento`.
    var avanzamentoFluido: (dal: Date, secondi: Int)? = nil
    /// Riga sotto il tempo (UI v6, tavola 6): «Poi Lat machine, 3 set da 8 a 12».
    var sottotitolo: String? = nil

    /// Pulsante principale: 19 e 15 pt come nelle tavole, che crescono con «Testo più grande».
    @ScaledMetric(relativeTo: .title3) private var dimensioneTitolo: CGFloat = 19
    @ScaledMetric(relativeTo: .subheadline) private var dimensioneDettaglio: CGFloat = 15

    private var testoTempo: some View {
        Text(tempo)
            .font(.piastra(64))
            .monospacedDigit()
            .foregroundStyle(coloreTesto)
            .frame(height: 56)
            .lineLimit(1)
    }

    var body: some View {
        // Con la barra del set a tempo gli spazi si stringono, così il dock resta alto 224 pt.
        VStack(alignment: .leading, spacing: avanzamento == nil ? 24 : 12) {
            VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(etichetta)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(coloreEtichetta)
                        .lineLimit(1)
                    if let azioneTempo {
                        Button(action: azioneTempo) {
                            HStack(spacing: 8) {
                                testoTempo
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(coloreTesto.opacity(0.8))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Passa tra cronometro e conto alla rovescia")
                    } else {
                        testoTempo
                    }
                    if let sottotitolo {
                        Text(sottotitolo)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(coloreEtichetta)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: 0)
                if let notaTempo {
                    Text(notaTempo)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(coloreEtichetta)
                        .lineLimit(1)
                        .padding(.bottom, 4)
                }
                if let secondario {
                    Button(action: secondario.azione) {
                        Text(secondario.titolo)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(coloreTesto)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(coloreTesto.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                }
            }
            if let fluido = avanzamentoFluido {
                TimelineView(.animation) { contesto in
                    BarraAvanzamento(valore: TimedText.progress(elapsed: contesto.date.timeIntervalSince(fluido.dal),
                                                                target: fluido.secondi),
                                     colore: coloreTesto)
                }
            } else if let avanzamento {
                BarraAvanzamento(valore: avanzamento, colore: coloreTesto)
            }
            }
            if let principale {
                Button(action: principale.azione) {
                    HStack(spacing: 12) {
                        if let icona = principale.icona {
                            Image(systemName: icona)
                                .font(.system(size: dimensioneTitolo, weight: .semibold))
                                .padding(.trailing, -4)
                        }
                        Text(principale.titolo)
                            .font(.system(size: dimensioneTitolo, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let dettaglio = principale.dettaglio {
                            Text(dettaglio)
                                .font(.system(size: dimensioneDettaglio, weight: .medium))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(principale.testo)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(principale.sfondo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, avanzamento == nil ? 20 : 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, minHeight: 224, maxHeight: 224, alignment: .top)
        // Dock alto 224 pt fissi (la schermata ci si appoggia sopra): il testo cresce fino a xxxLarge.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
                .fill(sfondo)
                .shadow(color: bordoSopra ? Color.inchiostro.opacity(0.08) : .clear, radius: 0, x: 0, y: -1)
        }
    }
}

/// Barra del set a tempo (UI v5): parte passata nel colore del testo, il resto in trasparenza.
struct BarraAvanzamento: View {
    let valore: Double
    let colore: Color

    var body: some View {
        GeometryReader { spazio in
            ZStack(alignment: .leading) {
                Capsule().fill(colore.opacity(0.14))
                Capsule().fill(colore)
                    .frame(width: spazio.size.width * min(1, max(0, valore)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Togli set scorrendo

/// Una sola piastra aperta alla volta: chi si apre lo dice qui, le altre si richiudono.
final class ScorriAperte: ObservableObject {
    static let shared = ScorriAperte()
    @Published var aperta: UUID?
    func chiudiTutte() { if aperta != nil { aperta = nil } }

    /// Finché è nel futuro, il tocco sotto la piastra non deve aprire il dettaglio: il gesto di scorrimento
    /// e il tocco del pulsante sotto partono insieme, e al rilascio il pulsante scatterebbe lo stesso.
    var tocchiBloccatiFinoA = Date.distantPast
    var tocchiBloccati: Bool { Date() < tocchiBloccatiFinoA }
}

extension View {
    /// Richiude «Rimuovi» se la lista scorre in verticale (va messo sul contenitore che scorre).
    func chiudiScorriSeScorre() -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 8).onChanged { valore in
                if abs(valore.translation.height) > abs(valore.translation.width) {
                    ScorriAperte.shared.chiudiTutte()
                }
            }
        )
    }
}

/// Scorrendo a sinistra una piastra da fare compare «Rimuovi» (rosso, cestino): lo scorrimento si ferma quando
/// il pulsante è visibile per intero (oltre, resistenza elastica) e il set si toglie solo toccando «Rimuovi»,
/// senza conferma. Con «Rimuovi» aperto o durante lo scorrimento il tocco sulla piastra non apre il dettaglio:
/// la richiude. Una sola aperta alla volta. Il gesto parte solo se è orizzontale, così la pagina continua a
/// scorrere in verticale. Con `attivo` falso (piastre fatte, set in corso) non fa niente.
/// (L'editor della scheda usa lo scorrimento nativo della lista, con lo stesso comportamento.)
struct ScorriPerTogliere: ViewModifier {
    let attivo: Bool
    let togli: () -> Void

    @StateObject private var aperte = ScorriAperte.shared
    @State private var identita = UUID()
    @State private var spostamento: CGFloat = 0
    @State private var aperto = false
    @State private var orizzontale: Bool?
    /// Oltre la metà di «Rimuovi»: al rilascio resta aperto. Il superamento dà un colpo aptico.
    @State private var oltreMeta = false
    private let larghezza: CGFloat = 104

    @ViewBuilder
    func body(content: Content) -> some View {
        if attivo {
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.errore)
                    .overlay(alignment: .trailing) {
                        Button(action: rimuovi) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Rimuovi")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(width: 100)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)
                    }
                    .opacity(spostamento < 0 ? 1 : 0)
                content
                    // Il fondo copre il rosso solo mentre si scorre (ferma, la piastra da fare resta trasparente).
                    .background(Color.lamiera.opacity(spostamento < 0 ? 1 : 0),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.ombra.opacity(spostamento < 0 ? 0.12 : 0), radius: 6, x: 4, y: 0)
                    .overlay {
                        // Scorrendo o aperto: un tocco sulla piastra la richiude (non apre Correggi set).
                        if aperto || spostamento < 0 {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { chiudi() }
                        }
                    }
                    .offset(x: spostamento)
            }
            .simultaneousGesture(trascinamento)
            .accessibilityAction(named: "Rimuovi", rimuovi)
            .onChange(of: aperte.aperta) { _, nuova in
                if nuova != identita && (aperto || spostamento < 0) { chiudi() }
            }
        } else {
            content
        }
    }

    private var trascinamento: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { valore in
                if orizzontale == nil {
                    orizzontale = abs(valore.translation.width) > abs(valore.translation.height)
                    if orizzontale == false { aperte.chiudiTutte() }
                }
                guard orizzontale == true else { return }
                aperte.tocchiBloccatiFinoA = .distantFuture
                if aperte.aperta != identita { aperte.aperta = identita }
                spostamento = posizione(valore.translation.width)
                let passata = spostamento < -larghezza / 2
                if passata != oltreMeta {
                    oltreMeta = passata
                    if passata { Aptica.soglia.dai() }
                }
            }
            .onEnded { valore in
                defer {
                    orizzontale = nil
                    oltreMeta = false
                }
                guard orizzontale == true else { return }
                aperte.tocchiBloccatiFinoA = Date().addingTimeInterval(0.4)
                if posizione(valore.translation.width) < -larghezza / 2 {
                    withAnimation(.snappy) {
                        spostamento = -larghezza
                        aperto = true
                    }
                } else {
                    chiudi()
                }
            }
    }

    /// Posizione della piastra: ferma a «Rimuovi» tutto visibile, oltre solo una resistenza elastica.
    private func posizione(_ traslazione: CGFloat) -> CGFloat {
        let grezza = min(0, (aperto ? -larghezza : 0) + traslazione)
        guard grezza < -larghezza else { return grezza }
        let oltre = -larghezza - grezza
        return -larghezza - 24 * tanh(oltre / 60)
    }

    private func chiudi() {
        if aperte.aperta == identita { aperte.aperta = nil }
        withAnimation(.snappy) {
            spostamento = 0
            aperto = false
        }
    }

    private func rimuovi() {
        // La riga che prende il posto di quella tolta riparte chiusa.
        spostamento = 0
        aperto = false
        if aperte.aperta == identita { aperte.aperta = nil }
        withAnimation(.snappy) { togli() }
    }
}
