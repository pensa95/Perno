import Foundation

/// Ricerca, filtro e raggruppamento della libreria esercizi.
public enum LibrarySearch {
    /// Vero se `name` contiene `query`, senza badare a maiuscole e accenti. Query vuota = tutto.
    public static func matches(_ name: String, query: String) -> Bool {
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return needle.isEmpty || fold(name).contains(needle)
    }

    /// Sezioni per gruppo muscolare, nell'ordine dei gruppi; esercizi in ordine alfabetico.
    /// Restano solo i gruppi con almeno un esercizio dopo filtro e ricerca.
    public static func sections<Item>(
        _ items: [Item],
        group: (Item) -> MuscleGroup,
        name: (Item) -> String,
        filter: MuscleGroup?,
        query: String
    ) -> [(group: MuscleGroup, items: [Item])] {
        let visible = items.filter { item in
            (filter == nil || group(item) == filter) && matches(name(item), query: query)
        }
        return MuscleGroup.allCases.compactMap { (muscleGroup) -> (group: MuscleGroup, items: [Item])? in
            let inGroup = visible
                .filter { group($0) == muscleGroup }
                .sorted { fold(name($0)) < fold(name($1)) }
            return inGroup.isEmpty ? nil : (muscleGroup, inGroup)
        }
    }

    /// Riga sotto il nome: «Macchina», «Macchina, in Upper body», «Cavi, in Upper body e Gambe».
    public static func subtitle(equipment: Equipment, routines: [String]) -> String {
        let names = routines.reduce(into: [String]()) { result, name in
            if !result.contains(name) { result.append(name) }
        }
        guard let last = names.last else { return equipment.label }
        let list = names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " e " + last
        return "\(equipment.label), in \(list)"
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
    }
}

/// Controllo del nome di un nuovo esercizio.
public enum ExerciseName {
    public enum Check: Equatable, Sendable {
        /// Nome valido, già ripulito dagli spazi.
        case valid(String)
        case empty
        /// Esiste già un esercizio con lo stesso nome (maiuscole e accenti non contano).
        case duplicate
    }

    public static func check(_ name: String, existing: [String]) -> Check {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let folded = LibrarySearch.fold(trimmed)
        if existing.contains(where: { LibrarySearch.fold($0.trimmingCharacters(in: .whitespaces)) == folded }) {
            return .duplicate
        }
        return .valid(trimmed)
    }
}
