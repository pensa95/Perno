import SwiftUI
import SwiftData

/// Schermate dello Storico che si aprono una dentro l'altra (dettaglio sessione, dettaglio esercizio,
/// tutte le sessioni di un esercizio). Ogni rotta porta il nome della schermata a cui torna la freccia.
enum RottaStorico: Hashable {
    case sessione(UUID, indietro: String)
    case esercizio(UUID, indietro: String)
    case sessioniEsercizio(UUID, indietro: String)
}

extension View {
    /// Registra le schermate dello Storico nella pila di navigazione (va messo sulla radice della pila).
    func destinazioniStorico() -> some View {
        navigationDestination(for: RottaStorico.self) { rotta in
            DestinazioneStorico(rotta: rotta)
        }
    }
}

/// Schermata di una rotta: cerca la sessione o l'esercizio nel database.
struct DestinazioneStorico: View {
    let rotta: RottaStorico

    @Query private var sessioni: [WorkoutSession]
    @Query private var esercizi: [Exercise]

    var body: some View {
        switch rotta {
        case let .sessione(id, indietro):
            if let sessione = sessioni.first(where: { $0.id == id }) {
                DettaglioSessioneView(sessione: sessione, indietro: indietro)
            }
        case let .esercizio(id, indietro):
            if let esercizio = esercizi.first(where: { $0.id == id }) {
                DettaglioEsercizioView(esercizio: esercizio, indietro: indietro)
            }
        case let .sessioniEsercizio(id, indietro):
            if let esercizio = esercizi.first(where: { $0.id == id }) {
                SessioniEsercizioView(esercizio: esercizio, indietro: indietro)
            }
        }
    }
}
