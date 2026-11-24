import SwiftUI
import SwiftData
import PernoCore

/// I Schede (canvas principale, pagina Schede): le tue schede, «Nuova scheda» giallo,
/// «Libreria esercizi». Il piano settimanale ha una sezione a sé (Piano, richiesta del 24/11).
struct SchedeView: View {
    @Query(sort: \Routine.createdAt) private var schede: [Routine]
    @Query private var esercizi: [Exercise]
    @State private var nuovaScheda: Routine?
    /// Vero per creare subito una scheda e aprire l'editor («Crea la prima scheda» del primo avvio).
    var creaSubito: Binding<Bool> = .constant(false)
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TestataSezione(titolo: "Schede")

                Text("Le tue schede")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .padding(.top, 24)

                if !schede.isEmpty {
                    Pila {
                        ForEach(schede) { scheda in
                            NavigationLink {
                                EditorSchedaView(scheda: scheda)
                            } label: {
                                VocePila(titolo: scheda.name.isEmpty ? "Senza nome" : scheda.name,
                                         sottotitolo: scheda.riassunto)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                }

                PulsanteGiallo(titolo: "Nuova scheda", icona: "plus", azione: creaScheda)
                .padding(.top, 12)

                Pila {
                    NavigationLink {
                        LibreriaView(indietro: "Schede")
                    } label: {
                        VocePila(titolo: "Libreria esercizi", dettaglio: conteggioEsercizi)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $nuovaScheda) { scheda in
            EditorSchedaView(scheda: scheda)
        }
        .onAppear(perform: creaSeRichiesto)
        .onChange(of: creaSubito.wrappedValue) { _, _ in creaSeRichiesto() }
    }

    private func creaSeRichiesto() {
        guard creaSubito.wrappedValue else { return }
        creaSubito.wrappedValue = false
        creaScheda()
    }

    /// Crea una scheda vuota e apre l'editor.
    private func creaScheda() {
        let scheda = Routine(name: RoutineNames.new(existing: schede.map(\.name)))
        context.insert(scheda)
        try? context.save()
        nuovaScheda = scheda
    }

    private var conteggioEsercizi: String {
        esercizi.count == 1 ? "1 esercizio" : "\(esercizi.count) esercizi"
    }
}

#Preview {
    NavigationStack {
        SchedeView()
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
