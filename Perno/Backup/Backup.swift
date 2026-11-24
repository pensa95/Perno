import Foundation
import Observation
import SwiftData
import PernoCore

/// Backup automatico nella cartella scelta (app File, consigliata iCloud Drive).
/// A fine sessione scrive una copia nuova, poi cancella le più vecchie oltre le copie da tenere.
/// Il permesso sulla cartella è un security-scoped bookmark; se si perde (di solito dopo un rinnovo
/// dell'app) il backup non riesce e la Home mostra l'avviso finché un backup non riesce.
@Observable
final class Backup {
    private enum Chiave {
        static let cartella = "backup.cartella"
        static let nomeCartella = "backup.nomeCartella"
        static let posizione = "backup.posizione"
        static let ultimo = "backup.ultimo"
        static let ultimaSessione = "backup.ultimaSessione"
        static let copie = "backup.copie"
        static let copieNellaCartella = "backup.copieNellaCartella"
        static let piuVecchia = "backup.piuVecchia"
        static let fallito = "backup.fallito"
    }

    private let difese = UserDefaults.standard

    /// Nome della cartella («Palestra»); `nil` se non è ancora stata scelta.
    private(set) var nomeCartella: String?
    /// «iCloud Drive» o «Sul mio iPhone».
    private(set) var posizione: String?
    private(set) var ultimo: Date?
    private(set) var ultimaSessione: String?
    private(set) var copieNellaCartella = 0
    private(set) var piuVecchia: Date?
    /// L'ultimo tentativo non è riuscito (avviso in Home).
    private(set) var fallito = false
    /// Copie da tenere: 3, 5 o 10.
    var copie: Int {
        didSet { difese.set(copie, forKey: Chiave.copie) }
    }

    var cartellaScelta: Bool { difese.data(forKey: Chiave.cartella) != nil }

    init() {
        nomeCartella = difese.string(forKey: Chiave.nomeCartella)
        posizione = difese.string(forKey: Chiave.posizione)
        ultimo = difese.object(forKey: Chiave.ultimo) as? Date
        ultimaSessione = difese.string(forKey: Chiave.ultimaSessione)
        copieNellaCartella = difese.integer(forKey: Chiave.copieNellaCartella)
        piuVecchia = difese.object(forKey: Chiave.piuVecchia) as? Date
        fallito = difese.bool(forKey: Chiave.fallito)
        let salvate = difese.integer(forKey: Chiave.copie)
        copie = BackupFiles.keepChoices.contains(salvate) ? salvate : BackupFiles.defaultKeep
    }

    // MARK: Cartella

    /// Cartella scelta dall'app File: memorizza il permesso. `false` se non si può usare.
    @discardableResult
    func scegliCartella(_ url: URL) -> Bool {
        let accesso = url.startAccessingSecurityScopedResource()
        defer { if accesso { url.stopAccessingSecurityScopedResource() } }
        guard let segnalibro = try? url.bookmarkData() else {
            segnaFallito()
            return false
        }
        difese.set(segnalibro, forKey: Chiave.cartella)
        nomeCartella = url.lastPathComponent
        posizione = BackupText.location(path: url.path)
        difese.set(nomeCartella, forKey: Chiave.nomeCartella)
        difese.set(posizione, forKey: Chiave.posizione)
        return true
    }

    // MARK: Backup automatico

    /// Scrive un backup nella cartella (a fine sessione, o dopo aver scelto la cartella).
    /// Senza cartella scelta non fa niente.
    func esegui(_ context: ModelContext, dopo sessione: String? = nil, alle ora: Date = .now) {
        guard let segnalibro = difese.data(forKey: Chiave.cartella) else { return }
        do {
            var vecchio = false
            let cartella = try URL(resolvingBookmarkData: segnalibro, bookmarkDataIsStale: &vecchio)
            guard cartella.startAccessingSecurityScopedResource() else { throw CocoaError(.fileWriteNoPermission) }
            defer { cartella.stopAccessingSecurityScopedResource() }
            if vecchio, let nuovo = try? cartella.bookmarkData() {
                difese.set(nuovo, forKey: Chiave.cartella)
            }

            let dati = try BackupFile.dalDatabase(context, alle: ora).encoded()
            try scrivi(dati, in: cartella.appendingPathComponent(BackupFiles.name(for: ora)))

            // Prima si scrive, poi si cancellano le copie più vecchie.
            let presenti = try FileManager.default.contentsOfDirectory(atPath: cartella.path)
            var reali: [String: String] = [:]
            for nome in presenti { reali[Self.nomePulito(nome)] = nome }
            let cancellare = BackupFiles.toDelete(from: Array(reali.keys), keep: copie)
            for nome in cancellare {
                if let reale = reali[nome] {
                    try? FileManager.default.removeItem(at: cartella.appendingPathComponent(reale))
                }
            }
            let rimaste = BackupFiles.backups(in: Array(reali.keys)).filter { !cancellare.contains($0) }

            ultimo = ora
            ultimaSessione = sessione
            copieNellaCartella = rimaste.count
            piuVecchia = rimaste.last.flatMap { BackupFiles.date(fromName: $0) }
            fallito = false
            difese.set(ultimo, forKey: Chiave.ultimo)
            difese.set(ultimaSessione, forKey: Chiave.ultimaSessione)
            difese.set(copieNellaCartella, forKey: Chiave.copieNellaCartella)
            difese.set(piuVecchia, forKey: Chiave.piuVecchia)
            difese.set(false, forKey: Chiave.fallito)
        } catch {
            segnaFallito()
        }
    }

    private func segnaFallito() {
        fallito = true
        difese.set(true, forKey: Chiave.fallito)
    }

    /// Scrittura coordinata (la cartella può essere su iCloud Drive).
    private func scrivi(_ dati: Data, in url: URL) throws {
        var erroreCoordinamento: NSError?
        var erroreScrittura: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing,
                                       error: &erroreCoordinamento) { destinazione in
            do {
                try dati.write(to: destinazione, options: .atomic)
            } catch {
                erroreScrittura = error
            }
        }
        if let erroreCoordinamento { throw erroreCoordinamento }
        if let erroreScrittura { throw erroreScrittura }
    }

    /// I file di iCloud non ancora scaricati si chiamano «.nome.json.icloud».
    private static func nomePulito(_ nome: String) -> String {
        var pulito = nome
        if pulito.hasPrefix("."), pulito.hasSuffix(".icloud") {
            pulito = String(pulito.dropFirst().dropLast(".icloud".count))
        }
        return pulito
    }

    // MARK: A mano

    /// «Esporta adesso»: un file nella cartella temporanea, da condividere.
    func fileDaEsportare(_ context: ModelContext, alle ora: Date = .now) throws -> URL {
        let dati = try BackupFile.dalDatabase(context, alle: ora).encoded()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(BackupFiles.name(for: ora))
        try dati.write(to: url, options: .atomic)
        return url
    }

    /// Legge un backup scelto dall'app File.
    static func leggi(_ url: URL) throws -> BackupFile {
        let accesso = url.startAccessingSecurityScopedResource()
        defer { if accesso { url.stopAccessingSecurityScopedResource() } }
        var erroreCoordinamento: NSError?
        var risultato: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &erroreCoordinamento) { origine in
            risultato = Result { try Data(contentsOf: origine) }
        }
        if let erroreCoordinamento { throw erroreCoordinamento }
        return try BackupFile.decode(try risultato.get())
    }
}
