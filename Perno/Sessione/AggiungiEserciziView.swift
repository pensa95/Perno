import SwiftUI
import SwiftData
import PernoCore

/// Aggiungi esercizi (tavola 7, anche dalla Scaletta): ricerca, selezione multipla con il numero
/// d'ordine, «Aggiungi N esercizi». Solo per oggi: le schede non cambiano.
struct AggiungiEserciziView: View {
    let sessione: SessioneInCorso

    @Environment(\.dismiss) private var dismiss
    @Query private var libreria: [Exercise]
    @State private var ricerca = ""
    @State private var scelti: [UUID] = []

    private struct Sezione: Identifiable {
        let gruppo: MuscleGroup
        let esercizi: [Exercise]
        var id: MuscleGroup { gruppo }
    }

    private var sezioni: [Sezione] {
        LibrarySearch.sections(libreria, group: { $0.muscleGroup }, name: { $0.name }, filter: nil, query: ricerca)
            .map { Sezione(gruppo: $0.group, esercizi: $0.items) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(sezioni) { sezione in
                    VStack(spacing: 12) {
                        EtichettaSezione(sezione.gruppo.label)
                        Pila {
                            ForEach(sezione.esercizi) { esercizio in
                                riga(esercizio)
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
                Text("Il numero indica l'ordine. Set e ripetizioni partono da 3 × 8–12; li cambi in sessione con + set.")
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
                    .padding(.leading, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.immediately)
        .barraFissa {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aggiungi esercizi")
                            .font(.piastra(32))
                            .foregroundStyle(Color.inchiostro)
                        Text("Solo per oggi: le schede non cambiano")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.inchiostroTenue)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PulsanteGiallo(titolo: FreeSessionText.addButton(scelti.count), attivo: !scelti.isEmpty) {
                let perId = Dictionary(libreria.map { ($0.id, $0) }, uniquingKeysWith: { primo, _ in primo })
                sessione.aggiungi(scelti.compactMap { perId[$0] })
                dismiss()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .stileFoglio()
        .presentationDetents([.large])
    }

    private func riga(_ esercizio: Exercise) -> some View {
        let numero = scelti.firstIndex(of: esercizio.id).map { $0 + 1 }
        return Button {
            if let indice = scelti.firstIndex(of: esercizio.id) {
                scelti.remove(at: indice)
            } else {
                scelti.append(esercizio.id)
            }
        } label: {
            HStack(spacing: 12) {
                Group {
                    if numero != nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.suInchiostro)
                            .frame(width: 26, height: 26)
                            .background(Color.inchiostro, in: Circle())
                    } else {
                        Circle()
                            .strokeBorder(Color.linea, lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                }
                IconaGruppo(gruppo: esercizio.muscleGroup, dimensione: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(esercizio.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                    Text(FreeSessionText.librarySubtitle(
                        equipment: esercizio.equipment,
                        last: FreeSessionText.best(WorkoutSession.ultimiSetDiLavoro(esercizio))))
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let numero {
                    Text("\(numero)")
                        .font(.piastra(22))
                        .foregroundStyle(Color.inchiostro)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(numero != nil ? .isSelected : [])
    }
}
