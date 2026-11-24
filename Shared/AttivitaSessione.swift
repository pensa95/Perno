import ActivityKit
import AppIntents
import Foundation
import PernoCore

/// Live Activity della sessione (blocco schermo e Dynamic Island). Compilato nell'app e
/// nell'estensione: il contenuto è `LiveActivityState` di `PernoCore`, con i testi già pronti.
struct AttivitaSessioneAttributes: ActivityAttributes {
    typealias ContentState = LiveActivityState
    /// Id della sessione (`WorkoutSession.id`).
    var sessione: String
}

/// Indirizzo che apre la sessione nell'app (tocco sulla card, «Scegli esercizi», «Vai al riepilogo»).
enum IndirizziPerno {
    static let sessione = URL(string: "perno://sessione")!
}

/// Pulsanti della card: girano nel processo dell'app (anche con lo schermo bloccato), senza aprirla.
struct AzioneSessioneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Azione della sessione"
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @Parameter(title: "Azione")
    var azione: String

    init() {
        azione = LiveActivityAction.open.rawValue
    }

    init(_ azione: LiveActivityAction) {
        self.azione = azione.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let scelta = LiveActivityAction(rawValue: azione) {
            await AzioniSessione.esegui(scelta)
        }
        return .result()
    }
}

/// Chi esegue le azioni: l'app lo imposta all'avvio; nell'estensione resta vuoto.
@MainActor
enum AzioniSessione {
    static var gestore: ((LiveActivityAction) async -> Void)?

    static func esegui(_ azione: LiveActivityAction) async {
        await gestore?(azione)
    }
}
