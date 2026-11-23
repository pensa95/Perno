import Foundation
import SwiftData
import PernoCore

/// Migrazioni tra le versioni dello schema. Per ora c'è solo la v1.
enum PernoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum PernoStore {
    /// Archivio dell'app sul telefono, con la libreria esercizi caricata al primo avvio.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
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
