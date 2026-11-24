import SwiftUI
import SwiftData
import PernoCore

/// Le sezioni dell'app (Allenati, Schede, Piano, Storico, Impostazioni). Piano e Impostazioni sono
/// sezioni a sé dal 24/11 (prima il piano era in Schede e le Impostazioni dalla rotella della Home).
enum Sezione: CaseIterable {
    case allenati
    case schede
    case piano
    case storico
    case impostazioni

    var titolo: String {
        switch self {
        case .allenati: return "Allenati"
        case .schede: return "Schede"
        case .piano: return "Piano"
        case .storico: return "Storico"
        case .impostazioni: return "Impostazioni"
        }
    }

    var icona: String {
        switch self {
        case .allenati: return "dumbbell.fill"
        case .schede: return "text.alignleft"
        case .piano: return "calendar"
        case .storico: return "chart.bar"
        case .impostazioni: return "gearshape"
        }
    }
}

/// Apre un'altra sezione (per esempio «Cambia» nell'editor della scheda apre il Piano).
private struct ApriSezioneKey: EnvironmentKey {
    static let defaultValue: (Sezione) -> Void = { _ in }
}

extension EnvironmentValues {
    var apriSezione: (Sezione) -> Void {
        get { self[ApriSezioneKey.self] }
        set { self[ApriSezioneKey.self] = newValue }
    }
}

/// Radice dell'app: la barra delle sezioni è quella di sistema (TabView, cinque sezioni), così posizione,
/// materiale e comportamento sono uguali alle altre app iOS.
/// Tiene anche la sessione aperta: schermata intera, card in Home quando è ridotta e barra ridotta
/// sulle altre sezioni.
struct SezioniView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Backup.self) private var backup
    @Query(sort: \WorkoutSession.startedAt) private var sessioni: [WorkoutSession]
    @Query private var schede: [Routine]
    @AppStorage("primoAvvio.fatto") private var primoAvvioFatto = false
    /// «Crea la prima scheda» dal primo avvio: Schede crea la scheda e apre l'editor.
    @State private var creaPrimaScheda = false
    @State private var sezione: Sezione = .allenati
    /// Percorso dello Storico: «Vedi nello storico» apre il dettaglio della sessione.
    @State private var percorsoStorico: [RottaStorico] = []
    @State private var sessione: SessioneInCorso?
    @State private var schermoSessione = false
    /// Riepiloghi già chiusi in questa apertura (prima di eliminare la sessione, così nessuna vista
    /// legge una sessione già eliminata).
    @State private var riepiloghiChiusi: Set<UUID> = []
    /// Sessione interrotta aperta con «Chiudi e vai al riepilogo».
    @State private var riepilogoInterrotta: WorkoutSession?

    var body: some View {
        if mostraPrimoAvvio {
            PrimoAvvioView(fine: finePrimoAvvio)
        } else {
            sezioni
                .onAppear {
                    // Chi aveva già dati prima del primo avvio non lo vede mai.
                    if !primoAvvioFatto { primoAvvioFatto = true }
                }
        }
    }

    private var mostraPrimoAvvio: Bool {
        FirstRun.shouldShow(done: primoAvvioFatto, hasRoutines: !schede.isEmpty, hasSessions: !sessioni.isEmpty)
    }

    private func finePrimoAvvio(_ fine: PrimoAvvioView.Fine) {
        primoAvvioFatto = true
        switch fine {
        case .home:
            sezione = .allenati
        case .nuovaScheda:
            sezione = .schede
            creaPrimaScheda = true
        case .sessioneLibera:
            sezione = .allenati
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { avviaLibera() }
        }
    }

    private var sezioni: some View {
        TabView(selection: $sezione) {
            NavigationStack {
                HomeView(sessioneViva: sessione,
                         apriStorico: { registro in
                             percorsoStorico = [.sessione(registro.id, indietro: Sezione.storico.titolo)]
                             sezione = .storico
                         },
                         avvia: avvia,
                         avviaLibera: avviaLibera,
                         riprendi: riprendi,
                         apriSessione: { schermoSessione = true },
                         apriRiepilogo: { riepilogoInterrotta = $0 })
            }
            .tabItem { Label(Sezione.allenati.titolo, systemImage: Sezione.allenati.icona) }
            .tag(Sezione.allenati)
            NavigationStack { SchedeView(creaSubito: $creaPrimaScheda).destinazioniStorico() }
                .safeAreaInset(edge: .bottom) { barraRidotta }
                .tabItem { Label(Sezione.schede.titolo, systemImage: Sezione.schede.icona) }
                .tag(Sezione.schede)
            NavigationStack { PianoView() }
                .safeAreaInset(edge: .bottom) { barraRidotta }
                .tabItem { Label(Sezione.piano.titolo, systemImage: Sezione.piano.icona) }
                .tag(Sezione.piano)
            NavigationStack(path: $percorsoStorico) { StoricoView() }
                .safeAreaInset(edge: .bottom) { barraRidotta }
                .tabItem { Label(Sezione.storico.titolo, systemImage: Sezione.storico.icona) }
                .tag(Sezione.storico)
            NavigationStack { ImpostazioniView() }
                .safeAreaInset(edge: .bottom) { barraRidotta }
                .tabItem { Label(Sezione.impostazioni.titolo, systemImage: Sezione.impostazioni.icona) }
                .tag(Sezione.impostazioni)
        }
        .tint(Color.inchiostro)
        .environment(\.apriSezione) { sezione = $0 }
        .background {
            Color.clear
                .fullScreenCover(item: Binding(get: { riepilogoDaMostrare },
                                               set: { if $0 == nil { riepilogoInterrotta = nil } })) { registro in
                    riepilogo(registro)
                }
        }
        .onAppear(perform: chiudiInattive)
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { chiudiInattive() }
        }
        .background { OsservatoreAttivitaLive(sessione: sessione) }
        .onOpenURL { indirizzo in
            // Tocco sulla Live Activity, «Scegli esercizi», «Vai al riepilogo»: si apre la sessione.
            if indirizzo == IndirizziPerno.sessione, sessione != nil { schermoSessione = true }
        }
        .fullScreenCover(isPresented: $schermoSessione) {
            if let sessione {
                SessioneView(sessione: sessione,
                             riduci: { schermoSessione = false },
                             chiudi: {
                                 // «Salva sessione»: la sessione è nello storico, poi il backup.
                                 let nome = sessione.sessione.titolo
                                 schermoSessione = false
                                 self.sessione = nil
                                 backup.esegui(context, dopo: nome)
                             },
                             elimina: {
                                 let registro = sessione.sessione
                                 schermoSessione = false
                                 self.sessione = nil
                                 eliminaDopo(registro)
                             })
            }
        }
    }

    /// Riepilogo da mostrare senza schermata della sessione: la sessione interrotta chiusa con
    /// «Chiudi e vai al riepilogo», oppure quella chiusa da sola.
    private var riepilogoDaMostrare: WorkoutSession? {
        if let riepilogoInterrotta, !riepiloghiChiusi.contains(riepilogoInterrotta.id) {
            return riepilogoInterrotta
        }
        return daRivedere
    }

    /// Riepilogo di una sessione interrotta (con «Continua» e «Completa», che la riprendono) o
    /// chiusa da sola (senza).
    @ViewBuilder
    private func riepilogo(_ registro: WorkoutSession) -> some View {
        let interrotta = registro.endedAt == nil
        let continua: (() -> Void)? = interrotta ? { riprendiDalRiepilogo(registro, completando: nil) } : nil
        let completa: ((SessionExercise) -> Void)? = interrotta
            ? { esercizio in riprendiDalRiepilogo(registro, completando: esercizio) } : nil
        RiepilogoView(sessione: registro,
                      fine: registro.fineRegistrata,
                      continua: continua,
                      completa: completa,
                      salva: {
                          registro.endedAt = registro.fineRegistrata
                          registro.isSaved = true
                          try? context.save()
                          riepilogoInterrotta = nil
                          backup.esegui(context, dopo: registro.titolo)
                      },
                      elimina: {
                          riepiloghiChiusi.insert(registro.id)
                          riepilogoInterrotta = nil
                          eliminaDopo(registro)
                      })
    }

    /// «Continua» o «Completa» nel riepilogo di una sessione interrotta: la sessione riprende
    /// (come con «Riprendi sessione») e, con «Completa», l'esercizio scelto diventa quello di adesso.
    private func riprendiDalRiepilogo(_ registro: WorkoutSession, completando esercizio: SessionExercise?) {
        riepilogoInterrotta = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            riprendi(registro)
            if let esercizio, let viva = sessione {
                viva.completa(esercizio)
            }
        }
    }

    /// Elimina dopo la chiusura della vista che la mostra (così nessuna vista legge una sessione eliminata).
    private func eliminaDopo(_ registro: WorkoutSession) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            context.delete(registro)
            try? context.save()
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
        sessione = SessioneInCorso(sessione: registro, riscaldamento: Impostazioni.riscaldamentoAttivo,
                                   context: context)
        schermoSessione = true
    }

    /// «Sessione libera»: senza esercizi, si scelgono strada facendo.
    private func avviaLibera() {
        guard sessione == nil else { return }
        let registro = WorkoutSession.avviaLibera(in: context)
        sessione = SessioneInCorso(sessione: registro, riscaldamento: Impostazioni.riscaldamentoAttivo,
                                   context: context)
        schermoSessione = true
    }

    /// «Riprendi sessione» dopo un'interruzione.
    private func riprendi(_ registro: WorkoutSession) {
        guard sessione == nil else { return }
        sessione = SessioneInCorso(sessione: registro, riprendi: true, context: context)
        schermoSessione = true
    }
}

#Preview {
    SezioniView()
        .environment(Aspetto())
        .environment(Backup())
        .modelContainer(for: Routine.self, inMemory: true)
}
