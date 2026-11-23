import SwiftUI

/// Le tre sezioni dell'app, con la barra flottante in basso (Allenati, Schede, Storico).
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

struct SezioniView: View {
    @State private var sezione: Sezione = .allenati

    var body: some View {
        ZStack(alignment: .bottom) {
            switch sezione {
            case .allenati:
                NavigationStack { HomeView(apriStorico: { sezione = .storico }) }
            case .schede:
                NavigationStack { SchedeView() }
            case .storico:
                NavigationStack { InArrivoView(titolo: "Storico") }
            }

            BarraSezioni(sezione: $sezione)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .ignoresSafeArea(.container, edges: .bottom)
                .ignoresSafeArea(.keyboard)
        }
    }
}

/// Barra delle sezioni: capsula alta 64 pt, traslucida, voce attiva con fondo leggero.
struct BarraSezioni: View {
    @Binding var sezione: Sezione

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Sezione.allCases, id: \.self) { voce in
                let attiva = voce == sezione
                Button {
                    sezione = voce
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: voce.icona)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(height: 24)
                        Text(voce.titolo)
                            .font(.system(size: 11, weight: attiva ? .semibold : .medium))
                    }
                    .foregroundStyle(attiva ? Color.inchiostro : Color.inchiostroTenue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(attiva ? Color.inchiostro.opacity(0.08) : Color.clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(attiva ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(height: 64)
        .background {
            Capsule()
                .fill(Color.foglio.opacity(0.72))
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay {
            Capsule().strokeBorder(Color.inchiostro.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.inchiostro.opacity(0.12), radius: 12, y: 8)
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
