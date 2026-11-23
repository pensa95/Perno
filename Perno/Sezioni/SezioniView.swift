import SwiftUI
import SwiftData
import PernoCore

/// Le tre sezioni dell'app (Allenati, Schede, Storico).
enum Sezione: CaseIterable {
    case allenati
    case schede
    case storico

    var titolo: String {
        switch self {
        case .allenati: return "Allenati"
        case .schede: return "Schede"
        case .storico: return "Storico"
        }
    }

    var icona: String {
        switch self {
        case .allenati: return "dumbbell.fill"
        case .schede: return "text.alignleft"
        case .storico: return "chart.bar"
        }
    }
}

/// Radice dell'app: la barra delle sezioni è quella di sistema (TabView), così posizione,
/// materiale e comportamento sono uguali alle altre app iOS.
/// Tiene anche la sessione aperta: schermata intera, card in Home quando è ridotta e barra ridotta
/// sulle altre sezioni.
struct SezioniView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSession.startedAt) private var sessioni: [WorkoutSession]
    @State private var sezione: Sezione = .allenati
    @State private var sessione: SessioneInCorso?
    @State private var schermoSessione = false
    /// Riepiloghi già chiusi in questa apertura (prima di eliminare la sessione, così nessuna vista
    /// legge una sessione già eliminata).
    @State private var riepiloghiChiusi: Set<UUID> = []

    var body: some View {
        TabView(selection: $sezione) {
            NavigationStack {
                HomeView(sessioneViva: sessione,
                         apriStorico: { sezione = .storico },
                         avvia: avvia,
                         avviaLibera: avviaLibera,
                         riprendi: riprendi,
                         apriSessione: { schermoSessione = true })
            }
            .tabItem { Label(Sezione.allenati.titolo, systemImage: Sezione.allenati.icona) }
            .tag(Sezione.allenati)
            NavigationStack { SchedeView() }
                .safeAreaInset(edge: .bottom) { barraRidotta }
                .tabItem { Label(Sezione.schede.titolo, systemImage: Sezione.schede.icona) }
                .tag(Sezione.schede)
            NavigationStack { InArrivoView(titolo: Sezione.storico.titolo) }
                .safeAreaInset(edge: .bottom) { barraRidotta }
                .tabItem { Label(Sezione.storico.titolo, systemImage: Sezione.storico.icona) }
                .tag(Sezione.storico)
        }
        .tint(Color.inchiostro)
        .background {
            Color.clear
                .fullScreenCover(item: Binding(get: { daRivedere }, set: { _ in })) { registro in
                    RiepilogoChiusaView(sessione: registro,
                                        salva: {
                                            registro.isSaved = true
                                            try? context.save()
                                        },
                                        elimina: {
                                            riepiloghiChiusi.insert(registro.id)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                                context.delete(registro)
                                                try? context.save()
                                            }
                                        })
                }
        }
        .onAppear(perform: chiudiInattive)
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { chiudiInattive() }
        }
        .fullScreenCover(isPresented: $schermoSessione) {
            if let sessione {
                SessioneView(sessione: sessione,
                             riduci: { schermoSessione = false },
                             chiudi: {
                                 schermoSessione = false
                                 self.sessione = nil
                             })
            }
        }
    }

    /// Sessione chiusa da sola, non ancora salvata: alla riapertura si vede il suo riepilogo.
    private var daRivedere: WorkoutSession? {
        guard !schermoSessione else { return nil }
        return sessioni.last {
            $0.closedAutomatically && !$0.isSaved && $0.endedAt != nil && !riepiloghiChiusi.contains($0.id)
        }
    }

    /// Chiusura automatica: dopo 3 ore senza attività la sessione (aperta o interrotta) si chiude
    /// all'ultimo «Set fatto».
    private func chiudiInattive() {
        let ora = Date.now
        if let viva = sessione, AutoClose.isDue(lastActivity: viva.sessione.lastActivityAt, now: ora) {
            schermoSessione = false
            sessione = nil
        }
        var chiuse = false
        for registro in sessioni where registro.endedAt == nil
            && AutoClose.isDue(lastActivity: registro.lastActivityAt, now: ora) {
            let ultimoSet = registro.exercises.flatMap(\.sets).compactMap(\.endedAt).max()
            registro.endedAt = AutoClose.end(lastSetEnd: ultimoSet, lastActivity: registro.lastActivityAt)
            registro.closedAutomatically = true
            registro.isSaved = false
            chiuse = true
        }
        if chiuse { try? context.save() }
    }

    @ViewBuilder
    private var barraRidotta: some View {
        if let sessione, !schermoSessione {
            BarraSessione(sessione: sessione) { schermoSessione = true }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    /// «Inizia …»: crea il registro dalla scheda e apre la schermata della sessione.
    private func avvia(_ scheda: Routine) {
        guard sessione == nil, !scheda.entries.isEmpty else { return }
        let registro = WorkoutSession.avvia(da: scheda, in: context)
        sessione = SessioneInCorso(sessione: registro, context: context)
        schermoSessione = true
    }

    /// «Sessione libera»: senza esercizi, si scelgono strada facendo.
    private func avviaLibera() {
        guard sessione == nil else { return }
        let registro = WorkoutSession.avviaLibera(in: context)
        sessione = SessioneInCorso(sessione: registro, context: context)
        schermoSessione = true
    }

    /// «Riprendi sessione» dopo un'interruzione.
    private func riprendi(_ registro: WorkoutSession) {
        guard sessione == nil else { return }
        sessione = SessioneInCorso(sessione: registro, riprendi: true, context: context)
        schermoSessione = true
    }
}

/// Sezione non ancora costruita (Storico arriva con le settimane 5–6).
struct InArrivoView: View {
    let titolo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(.piastra(40))
                .foregroundStyle(Color.inchiostro)
            Text("Arriva in una delle prossime build.")
                .font(.body)
                .foregroundStyle(Color.inchiostroTenue)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SezioniView()
        .modelContainer(for: Routine.self, inMemory: true)
}
