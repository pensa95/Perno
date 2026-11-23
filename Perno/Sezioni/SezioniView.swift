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
struct SezioniView: View {
    @State private var sezione: Sezione = .allenati

    var body: some View {
        TabView(selection: $sezione) {
            NavigationStack { HomeView(apriStorico: { sezione = .storico }) }
                .tabItem { Label(Sezione.allenati.titolo, systemImage: Sezione.allenati.icona) }
                .tag(Sezione.allenati)
            NavigationStack { SchedeView() }
                .tabItem { Label(Sezione.schede.titolo, systemImage: Sezione.schede.icona) }
                .tag(Sezione.schede)
            NavigationStack { InArrivoView(titolo: Sezione.storico.titolo) }
                .tabItem { Label(Sezione.storico.titolo, systemImage: Sezione.storico.icona) }
                .tag(Sezione.storico)
        }
        .tint(Color.inchiostro)
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
