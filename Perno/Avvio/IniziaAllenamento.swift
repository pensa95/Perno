import AppIntents
import SwiftUI

/// Richiesta di «Inizia allenamento» (Tasto Azione, Siri, Comandi rapidi, C12): l'intent apre l'app e lascia
/// qui la richiesta; la Home la prende e avvia la scheda di oggi, o riprende la sessione aperta o interrotta.
@Observable
final class RichiestaAvvio {
    static let shared = RichiestaAvvio()
    var inAttesa = false
}

struct IniziaAllenamentoIntent: AppIntent {
    static var title: LocalizedStringResource = "Inizia allenamento"
    static var description = IntentDescription("Apre Perno e inizia la scheda di oggi, o riprende la sessione aperta.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        RichiestaAvvio.shared.inAttesa = true
        return .result()
    }
}

/// Il comando compare in Comandi rapidi e si può assegnare al Tasto Azione.
struct PernoComandi: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: IniziaAllenamentoIntent(),
            phrases: ["Inizia allenamento con \(.applicationName)", "Avvia \(.applicationName)"],
            shortTitle: "Inizia allenamento",
            systemImageName: "dumbbell.fill"
        )
    }
}
