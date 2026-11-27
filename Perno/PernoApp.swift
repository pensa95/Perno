import SwiftUI
import SwiftData
import Combine

@main
struct PernoApp: App {
    private let container: ModelContainer
    @State private var aspetto = Aspetto()
    @State private var backup = Backup()
    /// Animazione d'ingresso (C2): solo all'avvio a freddo. Finché va, la Home sta sotto, nascosta e
    /// leggermente ingrandita, e l'animazione la porta a 1.
    @State private var mostraIngresso = true
    @State private var homeScala: CGFloat = 1.14
    @State private var homeOpacita: Double = 0
    @Environment(\.scenePhase) private var scenePhase
    /// Controllo periodico dell'aspetto dell'iPhone (chiaro/scuro automatico).
    private let orologioAspetto = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() {
        Impostazioni.registraPredefiniti()
        Impostazioni.applicaUnita()
        // Pulsanti della Live Activity: il gestore deve esserci anche se l'app parte in background.
        _ = AttivitaLive.shared
        do {
            container = try PernoStore.makeContainer()
        } catch {
            fatalError("Archivio dati non disponibile: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Sotto la Home mentre entra: nello stesso colore, così non traspare lo sfondo della finestra.
                Color.lamiera.ignoresSafeArea()
                SezioniView()
                    .scaleEffect(homeScala)
                    .opacity(homeOpacita)
                if mostraIngresso {
                    IngressoView(scuro: aspetto.sistema == .dark,
                                 homeScala: $homeScala,
                                 homeOpacita: $homeOpacita) {
                        mostraIngresso = false
                    }
                }
            }
            .environment(aspetto)
            .environment(backup)
            .preferredColorScheme(aspetto.scelto)
            .onReceive(orologioAspetto) { _ in aspetto.controllaSistema() }
        }
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { aspetto.controllaSistema() }
        }
        .modelContainer(container)
    }
}
