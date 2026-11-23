import SwiftUI
import SwiftData

@main
struct PernoApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try PernoStore.makeContainer()
        } catch {
            fatalError("Archivio dati non disponibile: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            BenvenutoView()
        }
        .modelContainer(container)
    }
}
