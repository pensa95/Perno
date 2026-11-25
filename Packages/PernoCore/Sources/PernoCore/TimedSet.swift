import Foundation

// Set a tempo in sessione (UI v5). Il ciclo è lo stesso dei set a ripetizioni: cambia solo il
// timer del set, che va alla rovescia dalla durata obiettivo e a zero chiude il set da solo.
// Nella macchina a stati un set a tempo ha 0 ripetizioni; la durata sta nel registro.

public enum TimedPlan {
    /// Set di un esercizio a tempo: niente avvicinamenti, tutti set di lavoro con il peso dato
    /// (0 senza peso) e 0 ripetizioni.
    public static func sets(count: Int, weight: Double) -> [PlannedSet] {
        Array(repeating: PlannedSet(kind: .work, weight: max(0, weight), reps: 0), count: max(0, count))
    }
}

public enum TimedText {
    /// «10 × 0:45» con il peso, «0:45» senza (`weight` nil).
    public static func value(seconds: Int, weight: Double?) -> String {
        let time = Clock.text(Double(seconds))
        guard let weight else { return time }
        return "\(Units.show(weight)) × \(time)"
    }

    /// «Esercizio 5 di 5, 3 set da 0:45».
    public static func exerciseHeader(position: Int, count: Int, sets: Int, seconds: Int) -> String {
        "Esercizio \(position) di \(count), \(sets) set da \(Clock.text(Double(seconds)))"
    }

    /// Etichetta del dock: «Set 1 in corso, mancano».
    public static func inProgress(_ kind: SetKind, _ number: Int) -> String {
        SessionText.inProgress(kind, number) + ", mancano"
    }

    /// Accanto al tempo del dock: «di 0:45».
    public static func of(seconds: Int) -> String {
        "di \(Clock.text(Double(seconds)))"
    }

    /// Tempo che manca, arrotondato in su: «0:45» appena parte, «0:00» allo zero.
    public static func remaining(elapsed: TimeInterval, target: Int) -> String {
        Clock.text(ceil(max(0, Double(target) - max(0, elapsed))))
    }

    /// Parte di tempo già passata, da 0 a 1 (barra del dock e della Live Activity).
    public static func progress(elapsed: TimeInterval, target: Int) -> Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, elapsed / Double(target)))
    }

    /// Secondi fatti di un set chiuso dopo `duration`: mai oltre l'obiettivo (a zero si chiude da solo).
    public static func secondsDone(duration: TimeInterval, target: Int) -> Int {
        min(max(0, target), max(0, Int(duration.rounded())))
    }

    /// Avviso dopo il set: «Set 1, 10 ×» con il peso, «Set 1» senza (la durata è nel −/+ accanto).
    public static func noticeTitle(_ kind: SetKind, _ number: Int, weight: Double?) -> String {
        guard let weight else { return SessionText.shortName(kind, number) }
        return SessionText.noticeTitle(kind, number, weight: weight)
    }

    /// Riga sotto l'avviso: chiuso a zero o prima.
    public static func noticeDetail(seconds: Int, target: Int) -> String {
        seconds >= target
            ? "A zero il set si chiude da solo."
            : "Chiuso prima dello zero: salvato il tempo fatto. −/+ di 5 s."
    }

    /// Nota sulla piastra fatta: «pieno» se arrivato a zero, altrimenti «di 0:45».
    public static func doneNote(seconds: Int, target: Int) -> String {
        seconds >= target ? "pieno" : of(seconds: target)
    }

    /// Durata scritta col tastierino: «45», «0:45», «1:30».
    public static func parse(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        let seconds: Int?
        switch parts.count {
        case 1:
            seconds = Int(parts[0])
        case 2:
            guard let minutes = Int(parts[0]), let secs = Int(parts[1]), (0..<60).contains(secs) else { return nil }
            seconds = minutes * 60 + secs
        default:
            seconds = nil
        }
        guard let seconds, seconds > 0 else { return nil }
        return DurationLimits.clamp(seconds)
    }
}
