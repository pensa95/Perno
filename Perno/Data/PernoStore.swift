import Foundation
import SwiftData
import PernoCore

/// Migrazioni tra le versioni dello schema.
enum PernoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3]
    }

    /// v1 → v2: solo campi nuovi con un valore predefinito (tutto a ripetizioni, come prima).
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)

    /// v2 → v3 (UI v6): campi nuovi facoltativi o con un valore predefinito, poi i valori iniziali:
    /// - ogni voce della scheda riceve la sua identità e il recupero scelto fino a oggi nelle Impostazioni
    ///   (cronometro / alla rovescia, «Parti da solo»), così chi aggiorna non perde la sua scelta;
    /// - le sessioni aperte si legano alla loro scheda (per T12) e i loro esercizi prendono lo stesso recupero.
    static let v2ToV3 = MigrationStage.custom(fromVersion: SchemaV2.self, toVersion: SchemaV3.self,
                                              willMigrate: nil, didMigrate: { context in
        let difese = UserDefaults.standard
        let modo = difese.string(forKey: Impostazioni.modoRecupero).flatMap(RestMode.init(rawValue:)) ?? .stopwatch
        let daSolo = difese.bool(forKey: Impostazioni.partiDaSolo)

        for voce in try context.fetch(FetchDescriptor<SchemaV3.RoutineEntry>()) {
            if voce.entryID == nil { voce.entryID = UUID() }
            voce.restModeRaw = modo.rawValue
            voce.autoStartAfterRest = daSolo
        }
        let aperte = try context.fetch(FetchDescriptor<SchemaV3.WorkoutSession>()).filter { $0.endedAt == nil }
        for sessione in aperte {
            let esercizi = sessione.orderedExercises
            for esercizio in esercizi {
                esercizio.restModeRaw = modo.rawValue
                esercizio.autoStartAfterRest = daSolo
            }
            guard let scheda = sessione.routine else { continue }
            let voci = scheda.orderedEntries.compactMap { voce in
                voce.entryID.map { (id: $0, exercise: voce.exercise?.id) }
            }
            let legami = RoutineLink.match(session: esercizi.map { $0.exercise?.id }, routine: voci)
            for (esercizio, legame) in zip(esercizi, legami) {
                esercizio.routineEntryID = legame
            }
        }
        try context.save()
    })
}

enum PernoStore {
    /// Archivio dell'app sul telefono, con la libreria esercizi caricata al primo avvio.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration = ModelConfiguration(schema: schema)
        let container = try ModelContainer(for: schema, migrationPlan: PernoMigrationPlan.self,
                                           configurations: configuration)
        try seedLibraryIfNeeded(ModelContext(container))
        return container
    }

    private static let librarySeededKey = "librarySeeded"

    /// Inserisce gli esercizi precaricati una sola volta: se poi l'utente ne elimina uno, non torna.
    static func seedLibraryIfNeeded(_ context: ModelContext, defaults: UserDefaults = .standard) throws {
        guard !defaults.bool(forKey: librarySeededKey) else { return }
        let existingKeys = Set(try context.fetch(FetchDescriptor<Exercise>()).compactMap(\.builtInKey))
        for entry in ExerciseLibrary.builtIn where !existingKeys.contains(entry.key) {
            context.insert(Exercise(entry: entry))
        }
        try context.save()
        defaults.set(true, forKey: librarySeededKey)
    }
}
