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
            ? "Arrivato a zero: il set si chiude da solo."
            : "Chiuso prima: salvato il tempo fatto."
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

// MARK: - Progressione e confronto con la volta prima

/// Un set a tempo fatto: obiettivo e durata fatta, in secondi, con il peso (in chili).
public struct TimedSet: Equatable, Sendable {
    public var target: Int
    public var seconds: Int
    public var weight: Double

    public init(target: Int, seconds: Int, weight: Double = 0) {
        self.target = target
        self.seconds = seconds
        self.weight = weight
    }
}

public enum TimedProgression {
    /// Durata obiettivo di oggi. Se l'ultima volta ha tenuto l'obiettivo in tutti i set, +5 s;
    /// altrimenti lo stesso obiettivo dell'ultima volta. Mai sotto la durata della scheda.
    public static func target(base: Int, last: [TimedSet]) -> Int {
        guard let lastTarget = last.map(\.target).max() else { return DurationLimits.clamp(base) }
        let held = last.allSatisfy { $0.seconds >= $0.target }
        let next = held ? lastTarget + DurationLimits.progressionStep : lastTarget
        return DurationLimits.clamp(max(base, next))
    }
}

extension TimedText {
    /// Sulla piastra di adesso: «+5 s» rispetto alla durata fatta la volta prima; `nil` se uguale.
    public static func delta(today: Int, before: Int) -> String? {
        let difference = today - before
        guard difference != 0 else { return nil }
        return (difference > 0 ? "+" : "−") + "\(abs(difference)) s"
    }

    /// «prima 10 × 0:40» (o «prima 0:40» senza peso).
    public static func before(seconds: Int, weight: Double?) -> String {
        "prima " + value(seconds: seconds, weight: weight)
    }
}

extension SessionSummary {
    /// Record a tempo: la durata più lunga di oggi supera tutte quelle delle volte prima.
    /// Serve almeno una volta prima, come per i record a ripetizioni.
    public static func timedRecord(exercise: String, today: [TimedSet], previous: [TimedSet],
                                   withWeight: Bool) -> Record? {
        guard let best = today.filter({ $0.seconds > 0 }).max(by: { $0.seconds < $1.seconds }),
              let previousBest = previous.map(\.seconds).max(),
              best.seconds > previousBest else { return nil }
        return Record(exercise: exercise, lift: Lift(weight: best.weight, reps: 0),
                      seconds: best.seconds, withWeight: withWeight)
    }

    /// Chili dei set fatti: i set a tempo non contano (non hanno ripetizioni).
    public static func liftedKilogramsExcludingTimed(_ sets: [(kind: SetKind, weight: Double, reps: Int, timed: Bool)]) -> Double {
        HomeText.liftedKilograms(sets.filter { !$0.timed }.map { ($0.kind, $0.weight, $0.reps) })
    }
}
