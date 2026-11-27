import SwiftUI
import SwiftData
import PernoCore

/// K Libreria esercizi (tavola delle schermate aggiunte, pagina Schede).
/// Ricerca, filtro per gruppo muscolare, elenco per gruppo con attrezzo e schede di appartenenza;
/// «+» in alto apre «Nuovo esercizio».
struct LibreriaView: View {
    /// Nome della sezione a cui torna la freccia in testata.
    var indietro = "Schede"
    /// Se impostato, la libreria serve a scegliere: il tocco su un esercizio lo passa qui e torna indietro.
    var scegli: ((Exercise) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query private var esercizi: [Exercise]
    @State private var ricerca = ""
    @State private var filtro: MuscleGroup?
    @State private var nuovoAperto = false
    @State private var appenaCreato: Exercise?

    private struct Sezione: Identifiable {
        let gruppo: MuscleGroup
        let esercizi: [Exercise]
        var id: MuscleGroup { gruppo }
    }

    private var sezioni: [Sezione] {
        LibrarySearch.sections(esercizi, group: { $0.muscleGroup }, name: { $0.name },
                               filter: filtro, query: ricerca)
            .map { Sezione(gruppo: $0.group, esercizi: $0.items) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    PulsanteIndietro(titolo: indietro) { dismiss() }
                    Spacer()
                    PulsanteTondo(icona: "plus", etichetta: "Nuovo esercizio") { nuovoAperto = true }
                }

                Text("Libreria")
                    .font(.piastra(40))
                    .foregroundStyle(Color.inchiostro)
                    .padding(.top, 12)

                campoRicerca
                    .padding(.top, 16)

                filtri
                    .padding(.top, 12)

                VStack(spacing: 24) {
                    ForEach(sezioni) { sezione in
                        VStack(spacing: 12) {
                            EtichettaSezione(sezione.gruppo.label)
                            Pila {
                                ForEach(sezione.esercizi) { esercizio in
                                    if let scegli {
                                        Button {
                                            scegli(esercizio)
                                            dismiss()
                                        } label: {
                                            VocePila(titolo: esercizio.name, sottotitolo: sottotitolo(esercizio),
                                                     gruppo: esercizio.muscleGroup)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        NavigationLink(value: RottaStorico.esercizio(esercizio.id, indietro: "Libreria")) {
                                            VocePila(titolo: esercizio.name, sottotitolo: sottotitolo(esercizio),
                                                     gruppo: esercizio.muscleGroup)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    if sezioni.isEmpty {
                        Text("Nessun esercizio trovato.")
                            .font(.body)
                            .foregroundStyle(Color.inchiostroTenue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $nuovoAperto, onDismiss: sceltoDopoCreazione) {
            NuovoEsercizioView(gruppoIniziale: filtro ?? .chest) { appenaCreato = $0 }
        }
    }

    private var campoRicerca: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inchiostroTenue)
            TextField("Cerca un esercizio", text: $ricerca)
                .font(.body)
                .foregroundStyle(Color.inchiostro)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color.piastraFatta, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var filtri: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Scelta(titolo: "Tutti", scelta: filtro == nil) { filtro = nil }
                ForEach(MuscleGroup.allCases, id: \.self) { gruppo in
                    Scelta(titolo: gruppo.label, scelta: filtro == gruppo) { filtro = gruppo }
                }
            }
        }
        .accessibilityLabel("Gruppo muscolare")
    }

    /// In modalità scelta, l'esercizio appena creato si aggiunge subito.
    private func sceltoDopoCreazione() {
        guard let esercizio = appenaCreato, let scegli else { return }
        appenaCreato = nil
        scegli(esercizio)
        dismiss()
    }

    private func sottotitolo(_ esercizio: Exercise) -> String {
        let schede = esercizio.routineEntries
            .compactMap { $0.routine }
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.name)
        return LibrarySearch.subtitle(equipment: esercizio.equipment, routines: schede)
    }
}

#Preview {
    NavigationStack {
        LibreriaView()
    }
    .modelContainer(for: Exercise.self, inMemory: true)
}
