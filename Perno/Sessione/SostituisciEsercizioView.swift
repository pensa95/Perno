import SwiftUI
import SwiftData
import PernoCore

/// Sostituisci esercizio (UI v6, tavola 12), dal menu «…»: foglio come «Aggiungi esercizi» con la ricerca,
/// «Nuovo esercizio» e gli esercizi per gruppo con l'ultima volta. Il tocco su un esercizio sostituisce subito,
/// solo per oggi: i set fatti restano sul vecchio, quelli da fare passano al nuovo. La scheda non cambia.
/// «in scheda» segna gli esercizi che sono già nella sessione di oggi.
struct SostituisciEsercizioView: View {
    let sessione: SessioneInCorso
    let esercizio: Int

    @Environment(\.dismiss) private var dismiss
    @Query private var libreria: [Exercise]
    @State private var ricerca = ""
    @State private var nuovoAperto = false
    @State private var appenaCreato: Exercise?

    private var vecchio: SessionExercise { sessione.esercizi[esercizio] }

    private struct Sezione: Identifiable {
        let gruppo: MuscleGroup
        let esercizi: [Exercise]
        var id: MuscleGroup { gruppo }
    }

    private var sezioni: [Sezione] {
        let escluso = vecchio.exercise?.id
        let candidati = libreria.filter { $0.id != escluso }
        return LibrarySearch.sections(candidati, group: { $0.muscleGroup }, name: { $0.name }, filter: nil,
                                      query: ricerca)
            .map { Sezione(gruppo: $0.group, esercizi: $0.items) }
    }

    /// Esercizi già nella sessione di oggi («in scheda»).
    private var diOggi: Set<UUID> {
        Set(sessione.esercizi.compactMap { $0.exercise?.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    nuovoAperto = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Nuovo esercizio")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(Color.inchiostro)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        BordoTratteggiato(colore: Color.inchiostro.opacity(0.3), spessore: 1.5,
                                          trattino: 5, spazio: 4, raggio: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(sezioni) { sezione in
                    VStack(alignment: .leading, spacing: 12) {
                        EtichettaSezione(sezione.gruppo.label)
                        VStack(spacing: 4) {
                            ForEach(sezione.esercizi) { voce in
                                riga(voce)
                            }
                        }
                    }
                }
                if sezioni.isEmpty {
                    Text("Nessun esercizio trovato.")
                        .font(.body)
                        .foregroundStyle(Color.inchiostroTenue)
                        .padding(.leading, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.immediately)
        .barraFissa {
            VStack(spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sostituisci \(vecchio.name)")
                            .font(.piastra(32))
                            .foregroundStyle(Color.inchiostro)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text("Solo per oggi. I set fatti restano su \(vecchio.name), quelli da fare passano al nuovo.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.inchiostroTenue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    PulsanteTondo(icona: "xmark", etichetta: "Chiudi") { dismiss() }
                }

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
            .padding(.top, 24)
            .padding(.horizontal, 20)
        }
        .stileFoglio()
        .presentationDetents([.large])
        .sheet(isPresented: $nuovoAperto, onDismiss: {
            // Esercizio appena creato: sostituisce subito, poi il foglio si chiude.
            guard let creato = appenaCreato else { return }
            appenaCreato = nil
            scegli(creato)
        }) {
            NuovoEsercizioView(gruppoIniziale: vecchio.exercise?.muscleGroup ?? .chest) { appenaCreato = $0 }
        }
    }

    private func riga(_ voce: Exercise) -> some View {
        Button {
            scegli(voce)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(voce.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                    Text(FreeSessionText.librarySubtitle(
                        equipment: voce.equipment,
                        last: FreeSessionText.best(WorkoutSession.ultimiSetDiLavoro(voce))))
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if diOggi.contains(voce.id) {
                    Text("in scheda")
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inchiostroTenue)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Sostituisce \(vecchio.name) solo per oggi")
    }

    private func scegli(_ voce: Exercise) {
        sessione.sostituisci(esercizio, con: voce)
        dismiss()
    }
}
