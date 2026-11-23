import SwiftUI

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
    @State private var sezione: Sezione = .allenati
    @State private var sessione: SessioneInCorso?
    @State private var schermoSessione = false

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
