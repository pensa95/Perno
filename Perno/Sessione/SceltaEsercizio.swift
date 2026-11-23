import SwiftUI
import SwiftData
import PernoCore

/// Sessione libera (tavola 7): dopo il riscaldamento, o quando gli esercizi aggiunti sono finiti,
/// «Primo esercizio» / «Prossimo esercizio» con gli usati di recente e «Inizia». Il dock grafite
/// ha «Scegli esercizi».
struct SceltaEsercizio: View {
    let sessione: SessioneInCorso
    let scegli: () -> Void

    @Query private var libreria: [Exercise]

    /// Esercizi fatti in sessioni chiuse, dal più recente; senza quelli già di oggi.
    private var recenti: [Exercise] {
        let oggi = Set(sessione.esercizi.compactMap { $0.exercise?.id })
        let datati = libreria.compactMap { esercizio -> (Exercise, Date)? in
            guard !oggi.contains(esercizio.id) else { return nil }
            let ultima = esercizio.sessionExercises
                .compactMap { $0.session?.endedAt != nil ? $0.session?.startedAt : nil }
                .max()
            return ultima.map { (esercizio, $0) }
        }
        return datati.sorted { $0.1 > $1.1 }.prefix(5).map(\.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                if let riscaldamento = FreeSessionText.warmUpDone(sessione.durataRiscaldamento) {
                    Text(riscaldamento)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                Text(FreeSessionText.title(exercisesSoFar: sessione.esercizi.count))
                    .font(.piastra(40))
                    .foregroundStyle(Color.inchiostro)
            }
            .padding(.top, 24)

            Text("Scegli dalla libreria. Puoi aggiungerne altri mentre ti alleni.")
                .font(.body)
                .foregroundStyle(Color.inchiostroTenue)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            if !recenti.isEmpty {
                VStack(spacing: 12) {
                    EtichettaSezione("Usati di recente")
                    Pila {
                        ForEach(recenti) { esercizio in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(esercizio.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.inchiostro)
                                    Text(FreeSessionText.lastTime(
                                        FreeSessionText.best(WorkoutSession.ultimiSetDiLavoro(esercizio))))
                                        .font(.footnote)
                                        .foregroundStyle(Color.inchiostroTenue)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                PulsanteSecondario(titolo: "Inizia", altezza: 44, riempi: false) {
                                    sessione.aggiungi([esercizio])
                                }
                            }
                            .vocePila()
                        }
                    }
                }
                .padding(.top, 24)
            }
        }
    }
}
