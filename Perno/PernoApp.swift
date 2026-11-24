import SwiftUI
import SwiftData
import Combine

@main
struct PernoApp: App {
    private let container: ModelContainer
    @State private var aspetto = Aspetto()
    @Environment(\.scenePhase) private var scenePhase
    /// Controllo periodico dell'aspetto dell'iPhone (chiaro/scuro automatico).
    private let orologioAspetto = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() {
        Impostazioni.registraPredefiniti()
        Impostazioni.applicaUnita()
        do {
            container = try PernoStore.makeContainer()
        } catch {
            fatalError("Archivio dati non disponibile: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Il primo avvio (Benvenuto, cartella dei backup) arriva nella settimana 4.
            SezioniView()
                .environment(aspetto)
                .preferredColorScheme(aspetto.scelto)
                .onReceive(orologioAspetto) { _ in aspetto.controllaSistema() }
        }
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { aspetto.controllaSistema() }
        }
        .modelContainer(container)
    }
}
