import SwiftUI
import SwiftData
import PernoCore

/// I Schede e piano settimanale (canvas principale, pagina Schede).
/// Piano come 7 voci della pila (il tocco apre «Scegli la scheda del giorno»), le tue schede,
/// «Nuova scheda» giallo, «Libreria esercizi».
struct SchedeView: View {
    @Query(sort: \Routine.createdAt) private var schede: [Routine]
    @Query private var giorni: [PlanDay]
    @Query private var esercizi: [Exercise]
    @State private var giornoAperto: GiornoScelto?
    @State private var nuovaScheda: Routine?
    /// Vero per creare subito una scheda e aprire l'editor («Crea la prima scheda» del primo avvio).
    var creaSubito: Binding<Bool> = .constant(false)
    @Environment(\.modelContext) private var context

    private struct GiornoScelto: Identifiable {
        let weekday: Int
        var id: Int { weekday }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Schede")
                    .font(.piastra(40))
                    .foregroundStyle(Color.inchiostro)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Piano settimanale")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                    Text("Tocca un giorno per cambiare scheda")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                .padding(.top, 24)

                Pila {
                    ForEach(Weekday.all, id: \.self) { giorno in
                        Button {
                            giornoAperto = GiornoScelto(weekday: giorno)
                        } label: {
                            voceGiorno(giorno)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)

                Text("Le tue schede")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .padding(.top, 32)

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
        .sheet(item: $giornoAperto) { giorno in
            PianoGiornoView(weekday: giorno.weekday)
        }
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

    private func voceGiorno(_ giorno: Int) -> some View {
        let scheda = giorni.first { $0.weekday == giorno }?.routine
        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(Weekday.name(giorno))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
                if giorno == Weekday.of(.now) {
                    Text("oggi")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.suInchiostro)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.inchiostro, in: Capsule())
                }
            }
            .frame(minWidth: 104, alignment: .leading)

            Group {
                if let scheda {
                    Text(scheda.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                } else {
                    Text("Riposo")
                        .font(.body)
                        .foregroundStyle(Color.inchiostroTenue)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)

            FrecciaVoce()
        }
        .vocePila()
    }
}

#Preview {
    NavigationStack {
        SchedeView()
    }
    .modelContainer(for: Routine.self, inMemory: true)
}
