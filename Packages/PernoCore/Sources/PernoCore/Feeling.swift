import Foundation

/// «Com'è andato?» dopo un set di lavoro (UI v6): sostituisce la riserva. Salvato come valore grezzo.
/// Solo set di lavoro (anche a tempo), mai gli avvicinamenti. I dati vecchi restano con la riserva.
public enum Feeling: String, CaseIterable, Codable, Sendable {
    /// Si potrebbe alzare il peso.
    case light = "leggero"
    case justRight = "giusto"
    case hard = "faticoso"

    /// «Leggero», «Giusto», «Faticoso».
    public var title: String {
        switch self {
        case .light: return "Leggero"
        case .justRight: return "Giusto"
        case .hard: return "Faticoso"
        }
    }
}

/// Legame tra gli esercizi di una sessione e quelli della scheda da cui è partita (UI v6, task T10–T12):
/// serve a capire cosa è stato aggiunto o tolto dalla scheda mentre la sessione è aperta.
public enum RoutineLink {
    /// Abbina gli esercizi di una sessione (identificati dall'esercizio della libreria) alle voci della scheda,
    /// in ordine: ogni voce si usa una volta sola, la prima libera con lo stesso esercizio.
    /// Serve alla migrazione delle sessioni aperte, nate prima che il legame si salvasse.
    /// - Returns: per ogni esercizio della sessione, l'`id` della voce della scheda, o `nil` (aggiunto in sessione).
    public static func match(session exercises: [UUID?], routine entries: [(id: UUID, exercise: UUID?)]) -> [UUID?] {
        var usate = Set<UUID>()
        return exercises.map { esercizio in
            guard let esercizio,
                  let voce = entries.first(where: { $0.exercise == esercizio && !usate.contains($0.id) }) else {
                return nil
            }
            usate.insert(voce.id)
            return voce.id
        }
    }
}
