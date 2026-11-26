import Foundation

/// «Com'è andato?» dopo un set di lavoro (UI v6): sostituisce la riserva. Salvato come valore grezzo.
/// Solo set di lavoro (anche a tempo), mai gli avvicinamenti. I dati vecchi restano con la riserva.
public enum Feeling: String, CaseIterable, Codable, Sendable {
    /// Si potrebbe alzare il peso.
    case light = "leggero"
    case justRight = "giusto"
    case hard = "faticoso"

    /// «leggero», «giusto», «faticoso» (dettaglio sessione, sotto il valore).
    public var word: String { rawValue }

    /// «Leggero», «Giusto», «Faticoso».
    public var title: String {
        switch self {
        case .light: return "Leggero"
        case .justRight: return "Giusto"
        case .hard: return "Faticoso"
        }
    }
}

/// Testi dell'avviso dopo «Set fatto» (UI v6, tavole 5, 6, 7 e 16).
public enum NoticeText {
    /// L'avviso resta aperto 10 s; ogni tocco li rinnova.
    public static let duration: TimeInterval = 10
    public static let feelingQuestion = "Com'è andato?"

    /// «Set 1 fatto, 65 kg»; senza peso (a tempo senza «Con peso») «Set 1 fatto».
    public static func title(_ kind: SetKind, _ number: Int, weight: Double?) -> String {
        let name = SessionText.shortName(kind, number) + " fatto"
        guard let weight else { return name }
        return "\(name), \(Units.show(weight)) \(Units.unit.symbol)"
    }

    /// Sotto le ripetizioni: «+3 sull'obiettivo», «−1 sull'obiettivo», «come l'obiettivo».
    public static func repsDelta(done: Int, target: Int) -> String {
        let difference = done - target
        if difference == 0 { return "come l'obiettivo" }
        return (difference > 0 ? "+\(difference)" : "−\(-difference)") + " sull'obiettivo"
    }

    /// Parte della barretta ancora piena (tempo che resta prima che l'avviso si chiuda).
    public static func remaining(until deadline: Date, now: Date) -> Double {
        min(1, max(0, deadline.timeIntervalSince(now) / duration))
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

/// Note dell'esercizio nella card bianca della sessione (UI v6, tavole 2 e 13).
public enum ExerciseNoteText {
    /// Etichetta sopra la nota di oggi.
    public static let today = "Nota di oggi, la ritrovi la prossima volta"

    /// «Nota della volta scorsa, 19 nov».
    public static func lastTime(_ date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.component(.day, from: date)
        let month = ItalianDate.months[max(0, min(11, calendar.component(.month, from: date) - 1))]
        return "Nota della volta scorsa, \(day) \(month.prefix(3))"
    }

    /// La nota da mostrare dalla volta scorsa: quella dell'ultima volta che l'esercizio è stato fatto (la volta
    /// più recente), solo se non è vuota. Le volte prima non contano.
    public static func lastNote(_ times: [(date: Date, note: String)]) -> (date: Date, note: String)? {
        guard let last = times.max(by: { $0.date < $1.date }) else { return nil }
        let note = last.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? nil : (last.date, note)
    }
}
