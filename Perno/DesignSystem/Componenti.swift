import SwiftUI
import PernoCore

// Componenti propri della UI v3, da riusare ovunque (niente stili fuori da qui e da Theme).

// MARK: - Testi

/// Titolo di sezione: 13 pt semibold, inchiostro tenue, rientro di 4 pt.
struct EtichettaSezione: View {
    let testo: String

    init(_ testo: String) { self.testo = testo }

    var body: some View {
        Text(testo)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inchiostroTenue)
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Testata delle sezioni

/// Titolo delle tre sezioni (Allenati, Schede, Storico): Barlow 40, riga alta almeno 44 pt, 4 pt
/// sotto il bordo del contenuto (che parte 8 pt sotto l'area sicura). Uguale ovunque, così il
/// titolo non salta passando da una sezione all'altra.
struct TestataSezione<Azioni: View>: View {
    let titolo: String
    @ViewBuilder var azioni: Azioni

    var body: some View {
        HStack(spacing: 0) {
            Text(titolo)
                .font(.piastra(40))
                .foregroundStyle(Color.inchiostro)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            azioni
        }
        .frame(minHeight: 44)
        .padding(.top, 4)
    }
}

extension TestataSezione where Azioni == EmptyView {
    init(titolo: String) {
        self.init(titolo: titolo) { EmptyView() }
    }
}

// MARK: - Pila

/// Pila: ogni voce è una piastrina bianca a sé, raggio 8, 4 pt tra una e l'altra, nessun separatore.
struct Pila<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 4) { content }
    }
}

extension View {
    /// Fondo di una voce della pila: foglio, raggio 8, alta almeno `altezza` pt.
    func vocePila(altezza: CGFloat = 60) -> some View {
        self
            .padding(.vertical, 8)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, minHeight: altezza)
            .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Freccia a destra delle voci che aprono qualcosa.
struct FrecciaVoce: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.inchiostroTenue)
    }
}

/// Voce della pila con titolo, sottotitolo opzionale, dettaglio a destra opzionale e freccia.
struct VocePila: View {
    let titolo: String
    var sottotitolo: String? = nil
    var dettaglio: String? = nil
    var freccia = true
    /// Icona del gruppo muscolare a sinistra (D8, Libreria).
    var gruppo: MuscleGroup? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let gruppo {
                IconaGruppo(gruppo: gruppo, dimensione: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                if let sottotitolo {
                    Text(sottotitolo)
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let dettaglio {
                Text(dettaglio)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
            }
            if freccia {
                FrecciaVoce()
            }
        }
        .vocePila()
    }
}

/// Voce di scelta nei fogli (una sola scelta): titolo, sottotitolo e cerchio a destra.
struct VoceScelta: View {
    let titolo: String
    var sottotitolo: String? = nil
    let scelta: Bool
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titolo)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                    if let sottotitolo {
                        Text(sottotitolo)
                            .font(.footnote)
                            .foregroundStyle(Color.inchiostroTenue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    if scelta {
                        Circle().fill(Color.inchiostro)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.suInchiostro)
                    } else {
                        Circle().strokeBorder(Color.linea, lineWidth: 2)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .vocePila(altezza: 64)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(scelta ? .isSelected : [])
    }
}

// MARK: - Pulsanti

/// Pulsante principale giallo (uno solo per schermata), alto 64 pt.
struct PulsanteGiallo: View {
    let titolo: String
    var icona: String? = nil
    var attivo = true
    let azione: () -> Void

    /// 19 pt come nelle tavole, che crescono con «Testo più grande».
    @ScaledMetric(relativeTo: .title3) private var dimensione: CGFloat = 19

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 8) {
                if let icona {
                    Image(systemName: icona)
                        .font(.system(size: dimensione, weight: .semibold))
                }
                Text(titolo)
                    .font(.system(size: dimensione, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
                .padding(.horizontal, 16)
                .foregroundStyle(Color.suPerno)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color.perno, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!attivo)
        .opacity(attivo ? 1 : 0.4)
    }
}

/// Pulsante tondo con un'icona (X, +): fondo foglio, 44 pt (38 pt nella riga dell'esercizio, D5).
struct PulsanteTondo: View {
    let icona: String
    let etichetta: String
    var dimensione: CGFloat = 44
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Image(systemName: icona)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(width: dimensione, height: dimensione)
                .background(Color.foglio, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etichetta)
    }
}

/// Indietro in testata: freccia e nome della sezione.
struct PulsanteIndietro: View {
    let titolo: String
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text(titolo)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Color.inchiostro)
            .frame(minHeight: 44)
            .padding(.leading, -6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selettori

/// Capsula di scelta (filtri e selettori): scelta = inchiostro pieno, altrimenti foglio.
struct Scelta: View {
    let titolo: String
    let scelta: Bool
    var altezza: CGFloat = 36
    var riempi = false
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Text(titolo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scelta ? Color.suInchiostro : Color.inchiostro)
                .lineLimit(1)
                .padding(.horizontal, riempi ? 4 : 14)
                .frame(maxWidth: riempi ? .infinity : nil, minHeight: altezza)
                .background(scelta ? Color.inchiostro : Color.foglio,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(scelta ? .isSelected : [])
    }
}

/// Selettore a griglia su tre colonne (gruppo muscolare, attrezzo), voci alte 44 pt.
struct SelettoreGriglia<Valore: Hashable>: View {
    let valori: [Valore]
    @Binding var selezione: Valore
    let etichetta: (Valore) -> String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(valori, id: \.self) { valore in
                Scelta(titolo: etichetta(valore), scelta: valore == selezione, altezza: 44, riempi: true) {
                    selezione = valore
                }
            }
        }
    }
}

// MARK: - Foglio

/// Foglio standard: maniglia, titolo, X (chiude senza salvare), contenuto, pulsante giallo in fondo.
struct Foglio<Content: View>: View {
    let titolo: String
    var sottotitolo: String? = nil
    let pulsante: String
    var pulsanteAttivo = true
    let chiudi: () -> Void
    let conferma: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titolo)
                        .font(.piastra(32))
                        .foregroundStyle(Color.inchiostro)
                    if let sottotitolo {
                        Text(sottotitolo)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.inchiostroTenue)
                    }
                }
                Spacer()
                PulsanteTondo(icona: "xmark", etichetta: "Chiudi", azione: chiudi)
            }
            ScrollView {
                VStack(spacing: 24) { content }
            }
            .scrollBounceBehavior(.basedOnSize)
            PulsanteGiallo(titolo: pulsante, attivo: pulsanteAttivo, azione: conferma)
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .stileFoglio()
    }
}

extension View {
    /// Aspetto comune dei fogli: fondo lamiera, raggio 28, maniglia visibile.
    func stileFoglio() -> some View {
        self
            .background(Color.lamiera)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color.lamiera)
    }
}

// MARK: - Stepper

/// Stepper −/+ su fondo lamiera, raggio 12, numero in Barlow Condensed 26.
/// `riempi` allarga il controllo a tutto lo spazio (ripetizioni «da» e «a»).
struct StepperPiastra: View {
    let valore: String
    var riempi = false
    let menoAttivo: Bool
    let piuAttivo: Bool
    let etichettaMeno: String
    let etichettaPiu: String
    let meno: () -> Void
    let piu: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            tasto("minus", attivo: menoAttivo, etichetta: etichettaMeno, azione: meno)
            Text(valore)
                .font(.piastra(26))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
                .frame(minWidth: 36)
                .frame(maxWidth: riempi ? .infinity : nil)
                .numeriCheRuotano(valore)
            tasto("plus", attivo: piuAttivo, etichetta: etichettaPiu, azione: piu)
        }
        .frame(maxWidth: riempi ? .infinity : nil)
        .background(Color.lamiera, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tasto(_ icona: String, attivo: Bool, etichetta: String, azione: @escaping () -> Void) -> some View {
        Button(action: { Aptica.tick(piu: icona == "plus"); azione() }) {
            Image(systemName: icona)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(width: riempi ? 40 : 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!attivo)
        .opacity(attivo ? 1 : 0.3)
        .accessibilityLabel(etichetta)
    }
}

// MARK: - Numeri che ruotano

/// Le cifre ruotano quando il valore cambia (C7); con «Riduci movimento» cambiano di colpo.
private struct NumeriCheRuotano: ViewModifier {
    let valore: String
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText())
            .animation(menoMovimento ? nil : .snappy(duration: 0.25), value: valore)
    }
}

extension View {
    /// Da mettere su un `Text` con un valore che cambia (ripetizioni, peso, durata).
    func numeriCheRuotano(_ valore: String) -> some View {
        modifier(NumeriCheRuotano(valore: valore))
    }
}

// MARK: - Segmenti

/// Selettore a segmenti: fondo piastra fatta, voce scelta su una pillola (foglio nel chiaro, piastra nello
/// scuro, così resta più chiara del fondo) con ombra leggera. La pillola scorre da una voce all'altra.
struct SelettoreSegmenti<Valore: Hashable>: View {
    let valori: [Valore]
    @Binding var selezione: Valore
    let etichetta: (Valore) -> String
    @Namespace private var spazio
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    var body: some View {
        HStack(spacing: 2) {
            ForEach(valori, id: \.self) { valore in
                let scelto = valore == selezione
                Button {
                    if valore != selezione { Aptica.selezione.dai() }
                    selezione = valore
                } label: {
                    Text(etichetta(valore))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(scelto ? Color.inchiostro : Color.inchiostroTenue)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if scelto {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.segmentoScelto)
                                    .shadow(color: Color.ombra.opacity(0.12), radius: 1.5, y: 1)
                                    .matchedGeometryEffect(id: "pillola", in: spazio)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(scelto ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.piastraFatta, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(menoMovimento ? nil : .easeOut(duration: 0.12), value: selezione)
    }
}

// MARK: - Pulsante secondario

/// Pulsante secondario: fondo lamiera, bordo leggero, raggio 12 («Vedi nello storico», «Inizia» nelle voci).
struct PulsanteSecondario: View {
    let titolo: String
    var altezza: CGFloat = 52
    var riempi = true
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Text(titolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
                .padding(.horizontal, 20)
                .frame(maxWidth: riempi ? .infinity : nil, minHeight: altezza)
                .background(Color.lamiera, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.inchiostro.opacity(0.1), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendario della settimana

/// Calendario della settimana: spunta = fatto, bordo pieno = saltato, tratteggio = in programma
/// (oggi con fondo bianco), puntino = riposo (la linea si interrompe), capsula scura sulla lettera = oggi.
struct CalendarioSettimana: View {
    let giorni: [CalendarDay]

    var body: some View {
        HStack(spacing: spaziatura) {
            ForEach(giorni, id: \.weekday) { giorno in
                VStack(spacing: 6) {
                    Text(WeekCalendar.letter(giorno.weekday))
                        .font(.footnote.weight(giorno.isToday ? .semibold : .medium))
                        .foregroundStyle(giorno.isToday ? Color.foglio : Color.inchiostroTenue)
                        .frame(minWidth: 26, minHeight: 24)
                        .padding(.horizontal, 4)
                        .background(giorno.isToday ? Color.inchiostro : Color.clear, in: Capsule())
                    casella(giorno)
                        .frame(width: 36, height: 36)
                    Text(giorno.label)
                        .font(.caption.weight(giorno.isToday ? .semibold : .medium))
                        .foregroundStyle(giorno.isToday ? Color.inchiostro : Color.inchiostroTenue)
                        .lineLimit(1)
                        .frame(minHeight: 16)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(descrizione(giorno))
            }
        }
        // La linea è all'altezza del centro delle caselle, sotto la lettera alta 24 pt: oltre
        // xxxLarge la lettera crescerebbe e la linea non sarebbe più al centro.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(alignment: .top) {
            // Linea che unisce i giorni, all'altezza del centro delle caselle (24 + 6 + 18):
            // un tratto tra un giorno e l'altro, che si ferma a `stacco` dai quadrati e dai puntini.
            GeometryReader { geo in
                let n = giorni.count
                let colonna = (geo.size.width - spaziatura * CGFloat(max(n - 1, 0))) / CGFloat(max(n, 1))
                Path { tracciato in
                    guard n > 1 else { return }
                    for i in 0..<(n - 1) {
                        let centro = CGFloat(i) * (colonna + spaziatura) + colonna / 2
                        let prossimo = centro + colonna + spaziatura
                        let da = centro + metaIngombro(giorni[i]) + stacco
                        let a = prossimo - metaIngombro(giorni[i + 1]) - stacco
                        guard a > da else { continue }
                        tracciato.move(to: CGPoint(x: da, y: 48))
                        tracciato.addLine(to: CGPoint(x: a, y: 48))
                    }
                }
                .stroke(Color.linea, lineWidth: 1)
            }
        }
    }

    private let spaziatura: CGFloat = 4
    /// Spazio tra la linea e il quadrato o il puntino (uguale per tutti i giorni).
    private let stacco: CGFloat = 5

    /// Metà della larghezza di quello che c'è al centro della colonna: quadrato 36, puntino 4.
    private func metaIngombro(_ giorno: CalendarDay) -> CGFloat {
        giorno.status == .rest ? 2 : 18
    }

    @ViewBuilder
    private func casella(_ giorno: CalendarDay) -> some View {
        let forma = RoundedRectangle(cornerRadius: 8, style: .continuous)
        switch giorno.status {
        case .done:
            forma.fill(Color.piastra)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.piastraTesto)
                }
        case .skipped:
            forma.fill(Color.lamiera)
                .overlay { forma.strokeBorder(Color.bordoSaltato, lineWidth: 2) }
        case .planned:
            forma.fill(giorno.isToday ? Color.foglio : Color.lamiera)
                .overlay {
                    BordoTratteggiato(colore: giorno.isToday ? Color.bordoOggi : Color.bordoProgramma)
                }
        case .rest:
            Circle().fill(Color.puntoRiposo).frame(width: 4, height: 4)
        }
    }

    private func descrizione(_ giorno: CalendarDay) -> String {
        let stato: String
        switch giorno.status {
        case .done: stato = "fatto"
        case .skipped: stato = "saltato"
        case .planned: stato = giorno.isToday ? "oggi, da fare" : "in programma"
        case .rest: stato = "riposo"
        }
        let nome = giorno.label.isEmpty ? "" : "\(giorno.label), "
        return "\(Weekday.name(giorno.weekday)): \(nome)\(stato)"
    }
}

// MARK: - Bordo tratteggiato

/// Bordo tratteggiato di un quadrato arrotondato (come `strokeBorder`), con trattino e spazio
/// adattati perché il perimetro contenga un numero intero di periodi: il tratteggio resta uguale
/// anche dove il tracciato si chiude, senza un pezzo più corto.
struct BordoTratteggiato: View {
    let colore: Color
    var spessore: CGFloat = 2
    var trattino: CGFloat = 4
    var spazio: CGFloat = 3
    var raggio: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let rettangolo = CGRect(origin: .zero, size: geo.size)
                .insetBy(dx: spessore / 2, dy: spessore / 2)
            let percorso = RoundedRectangle(cornerRadius: max(raggio - spessore / 2, 0), style: .continuous)
                .path(in: rettangolo)
            let lunghezza = percorso.lunghezza
            let periodo = trattino + spazio
            let periodi = max((lunghezza / periodo).rounded(), 1)
            let scala = lunghezza > 0 ? lunghezza / (periodi * periodo) : 1
            percorso.stroke(colore, style: StrokeStyle(
                lineWidth: spessore,
                dash: [trattino * scala, spazio * scala],
                dashPhase: trattino * scala / 2
            ))
        }
    }
}

extension Path {
    /// Lunghezza del tracciato; le curve sono misurate su 24 punti.
    var lunghezza: CGFloat {
        var totale: CGFloat = 0
        var corrente = CGPoint.zero
        var inizio = CGPoint.zero
        let passi = 24

        func distanza(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot(b.x - a.x, b.y - a.y)
        }

        forEach { elemento in
            switch elemento {
            case .move(let punto):
                corrente = punto
                inizio = punto
            case .line(let punto):
                totale += distanza(corrente, punto)
                corrente = punto
            case .quadCurve(let punto, let controllo):
                var precedente = corrente
                for passo in 1...passi {
                    let t = CGFloat(passo) / CGFloat(passi)
                    let u = 1 - t
                    let x = u * u * corrente.x + 2 * u * t * controllo.x + t * t * punto.x
                    let y = u * u * corrente.y + 2 * u * t * controllo.y + t * t * punto.y
                    let nuovo = CGPoint(x: x, y: y)
                    totale += distanza(precedente, nuovo)
                    precedente = nuovo
                }
                corrente = punto
            case .curve(let punto, let controllo1, let controllo2):
                var precedente = corrente
                for passo in 1...passi {
                    let t = CGFloat(passo) / CGFloat(passi)
                    let u = 1 - t
                    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                    let x = a * corrente.x + b * controllo1.x + c * controllo2.x + d * punto.x
                    let y = a * corrente.y + b * controllo1.y + c * controllo2.y + d * punto.y
                    let nuovo = CGPoint(x: x, y: y)
                    totale += distanza(precedente, nuovo)
                    precedente = nuovo
                }
                corrente = punto
            case .closeSubpath:
                totale += distanza(corrente, inizio)
                corrente = inizio
            }
        }
        return totale
    }
}

// MARK: - Barra fissa con sfumatura

/// Barra (ricerca, testata) fissa sopra una lista. La barra ha il fondo pieno, quindi i contenuti non si vedono
/// sotto; appena la lista scorre, sotto il suo bordo compare una sfumatura dal colore del fondo al trasparente,
/// così i contenuti spariscono gradualmente. Con la lista in cima nessuna sfumatura. Da iOS 18 (su iOS 17 la
/// barra resta piena, senza sfumatura). `fondo` è il colore dietro la lista. Va messo sulla `ScrollView`.
/// (L'effetto nativo di iOS 26 lasciava vedere i contenuti sotto la barra: non si usa.)
struct BarraFissaSfumata<Barra: View>: ViewModifier {
    let fondo: Color
    @ViewBuilder let barra: () -> Barra
    @State private var scostamento: CGFloat = 0

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, nuovo in
                    scostamento = nuovo
                }
                .safeAreaInset(edge: .top, spacing: 0) { barraConFondo(sfumatura: true) }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) { barraConFondo(sfumatura: false) }
        }
    }

    private func barraConFondo(sfumatura: Bool) -> some View {
        barra()
            .frame(maxWidth: .infinity)
            .background(fondo)
            .overlay(alignment: .bottom) {
                if sfumatura {
                    LinearGradient(colors: [fondo, fondo.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 24)
                        .offset(y: 24)
                        .opacity(min(1, max(0, scostamento / 24)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    /// Mette `barra` fissa in cima alla lista, con la sfumatura sotto quando i contenuti scorrono (vedi `BarraFissaSfumata`).
    func barraFissa<Barra: View>(fondo: Color = .lamiera, @ViewBuilder _ barra: @escaping () -> Barra) -> some View {
        modifier(BarraFissaSfumata(fondo: fondo, barra: barra))
    }
}
