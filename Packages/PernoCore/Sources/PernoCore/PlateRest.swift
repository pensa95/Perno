import Foundation

/// Piastre della sessione (UI v6, tavole 4, 5, 5b, 5c, 6): recupero come piastrina tra i set, riga sottile
/// dei recuperi finiti, badge «+3» sulle piastre fatte oltre l'obiettivo.
public enum PlateText {
    /// Recupero misurato dopo ogni set dell'esercizio, per posizione del set: la pausa di recupero che parte
    /// da «Set fatto» di quel set. `nil` se il set non è fatto o il recupero non è ancora finito.
    public static func measuredRests(exercise: Int, setCount: Int, completed: [CompletedSet],
                                     pauses: [Pause]) -> [TimeInterval?] {
        var rests = [TimeInterval?](repeating: nil, count: max(setCount, 0))
        let rest = pauses.filter { $0.kind == .rest && $0.exerciseIndex == exercise }
        for set in completed where set.exerciseIndex == exercise && rests.indices.contains(set.setIndex) {
            if let pause = rest.first(where: { abs($0.start.timeIntervalSince(set.endedAt)) < 0.5 }) {
                rests[set.setIndex] = pause.duration
            }
        }
        return rests
    }

    /// Riga sottile del recupero finito: «recupero 2:12» (tempo misurato).
    public static func restDone(_ seconds: TimeInterval) -> String {
        "recupero \(SessionText.clock(seconds.rounded()))"
    }

    /// A destra della piastrina del recupero: «fissato a 2:00», «di solito 2:10»; `nil` senza tempi.
    public static func restNote(fixed: TimeInterval?, usual: TimeInterval?) -> String? {
        if let fixed, fixed > 0 { return "fissato a \(SessionText.clock(fixed))" }
        guard let usual else { return nil }
        return "di solito \(SessionText.clock(usual.rounded()))"
    }

    /// Badge sulle piastre fatte oltre l'obiettivo: «+3»; `nil` se non oltre.
    public static func overTarget(done: Int, target: Int) -> String? {
        done > target ? "+\(done - target)" : nil
    }

    /// Nota del set dopo il recupero in corso.
    public static let next = "prossimo"
}
