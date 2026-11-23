import SwiftUI
import SwiftData
import PernoCore

/// A Home (Allenati), nei due stati: oggi da fare e oggi fatto.
/// Calendario della settimana, «Oggi, giovedì» con la card della scheda di oggi, «Oppure» con le altre
/// schede e la sessione libera; a sessione fatta, numeri e «Prossimo allenamento».
struct HomeView: View {
    /// Apre la sezione Storico («Vedi nello storico»).
    var apriStorico: () -> Void = {}

    @Query(sort: \Routine.createdAt) private var schede: [Routine]
    @Query private var giorni: [PlanDay]
    @Query(sort: \WorkoutSession.startedAt) private var sessioni: [WorkoutSession]

    @Environment(\.modelContext) private var context
    @State private var sessioneAperta: SessioneInCorso?

    private var calendario: Calendar { .current }

    // MARK: Dati

    private var oggi: Int { Weekday.of(.now, calendar: calendario) }

    /// Scheda per giorno (solo i giorni con una scheda).
    private var piano: [Int: UUID] {
        var piano: [Int: UUID] = [:]
        for giorno in giorni {
            if let scheda = giorno.routine { piano[giorno.weekday] = scheda.id }
        }
        return piano
    }

    private var pianoImpostato: Bool { !giorni.isEmpty }

    private var finite: [WorkoutSession] { sessioni.filter { $0.endedAt != nil } }

    private var ultimaVolta: [UUID: Date] {
        var date: [UUID: Date] = [:]
        for sessione in finite {
            if let id = sessione.routine?.id { date[id] = max(date[id] ?? .distantPast, sessione.startedAt) }
        }
        return date
    }

    private var proposta: Routine? {
        let id = TodayPlan.proposal(weekday: oggi, plan: piano, planIsSet: pianoImpostato,
                                    routines: schede.map(\.id), lastDone: ultimaVolta)
        return schede.first { $0.id == id }
    }

    /// Sessione che rende «fatto» oggi: con la scheda in programma oggi; senza piano o nei giorni
    /// di riposo, qualunque sessione iniziata oggi.
    private var sessioneDiOggi: WorkoutSession? {
        let diOggi = finite.filter { calendario.isDateInToday($0.startedAt) }
        if pianoImpostato, let inProgramma = piano[oggi] {
            return diOggi.last { $0.routine?.id == inProgramma }
        }
        return diOggi.last
    }

    private var giorniCalendario: [CalendarDay] {
        WeekCalendar.days(
            today: .now,
            plan: piano,
            names: Dictionary(schede.map { ($0.id, $0.name) }, uniquingKeysWith: { primo, _ in primo }),
            sessions: finite.map { FinishedSession(start: $0.startedAt, routine: $0.routine?.id, name: $0.routineName) },
            calendar: calendario
        )
    }

    // MARK: Vista

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Allenati")
                        .font(.piastra(40))
                        .foregroundStyle(Color.inchiostro)
                    Spacer()
                    Button {
                        // Settimana 4: Impostazioni.
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.inchiostro)
                            .frame(width: 44, height: 44, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Impostazioni")
                }
                .padding(.top, 4)

                CalendarioSettimana(giorni: giorniCalendario)
                    .padding(.top, 28)

                if let sessione = sessioneDiOggi {
                    sezione(titoloOggi, sopra: 32) { cardFatto(sessione) }
                    if let prossimo = prossimoAllenamento {
                        sezione("Prossimo allenamento", sopra: 28) {
                            Pila { prossimo }
                        }
                    }
                } else if let scheda = proposta {
                    sezione(titoloOggi, sopra: 32) { cardDaFare(scheda) }
                    sezione("Oppure", sopra: 28) { altreScelte(escludendo: scheda) }
                } else {
                    sezione("Scegli un allenamento", sopra: 32) { altreScelte(escludendo: nil) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $sessioneAperta) { sessione in
            SessioneView(sessione: sessione) { sessioneAperta = nil }
        }
    }

    /// «Inizia …»: crea il registro dalla scheda e apre la schermata della sessione.
    private func avvia(_ scheda: Routine) {
        guard !scheda.entries.isEmpty else { return }
        let sessione = WorkoutSession.avvia(da: scheda, in: context)
        sessioneAperta = SessioneInCorso(sessione: sessione, context: context)
    }

    private var titoloOggi: String { "Oggi, \(Weekday.name(oggi).lowercased())" }

    private func sezione<Content: View>(_ titolo: String, sopra: CGFloat,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
            content()
        }
        .padding(.top, sopra)
    }

    // MARK: Card

    private func cardDaFare(_ scheda: Routine) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scheda.name)
                    .font(.piastra(48))
                    .foregroundStyle(Color.inchiostro)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(scheda.elencoConDurata)
                    .font(.subheadline)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            PulsanteGiallo(titolo: "Inizia \(scheda.name)", attivo: !scheda.entries.isEmpty) {
                avvia(scheda)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func cardFatto(_ sessione: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.piastra)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.piastraTesto)
                    }
                Text("Fatto")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
            }
            Text(sessione.titolo)
                .font(.piastra(48))
                .foregroundStyle(Color.inchiostro)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, -8)
            HStack(alignment: .top, spacing: 12) {
                numero(HomeText.duration(sessione.durata), "durata")
                numero("\(sessione.setFatti) set", "su \(sessione.setPrevisti)")
                numero(HomeText.volume(sessione.chiliSollevati), "kg sollevati")
            }
            PulsanteSecondario(titolo: "Vedi nello storico", azione: apriStorico)
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func numero(_ valore: String, _ etichetta: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(valore)
                .font(.piastra(30))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(etichetta)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Elenchi

    /// Le altre schede con «Inizia», poi la sessione libera.
    private func altreScelte(escludendo esclusa: Routine?) -> some View {
        Pila {
            ForEach(schede.filter { $0.id != esclusa?.id }) { scheda in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scheda.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inchiostro)
                        Text(scheda.riassunto)
                            .font(.footnote)
                            .foregroundStyle(Color.inchiostroTenue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PulsanteSecondario(titolo: "Inizia", altezza: 44, riempi: false) {
                        avvia(scheda)
                    }
                }
                .vocePila()
            }
            Button {
                // Settimana 3: sessione libera.
            } label: {
                VocePila(titolo: "Sessione libera", sottotitolo: "Scegli gli esercizi strada facendo")
            }
            .buttonStyle(.plain)
        }
    }

    /// «Gambe — Sabato, 4 esercizi» (solo con il piano impostato).
    private var prossimoAllenamento: VocePila? {
        guard let prossimo = TodayPlan.next(after: oggi, plan: piano),
              let scheda = schede.first(where: { $0.id == prossimo.routine }) else { return nil }
        let giorno = prossimo.weekday
        let quanti = scheda.orderedEntries.count
        let esercizi = quanti == 0 ? "nessun esercizio" : (quanti == 1 ? "1 esercizio" : "\(quanti) esercizi")
        return VocePila(titolo: scheda.name, sottotitolo: "\(Weekday.name(giorno)), \(esercizi)", freccia: false)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
