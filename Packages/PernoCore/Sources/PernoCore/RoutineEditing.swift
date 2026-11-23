import Foundation

// Logica dell'editor scheda e del foglio «Esercizio nella scheda».

/// Durate in minuti e secondi: «2:30», «0:45».
public enum Clock {
    public static func text(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let secs = total % 60
        return "\(total / 60):\(secs < 10 ? "0" : "")\(secs)"
    }
}

/// Limiti degli stepper.
public enum EntryLimits {
    public static let sets = 1...10
    public static let reps = 1...50
    public static let approaches = 0...3
    /// Recupero fissato: da 15 s a 10 minuti, a passi di 15 s.
    public static let rest: ClosedRange<Double> = 15...600
    public static let restStep: Double = 15
    public static let defaultFixedRest: Double = 120

    /// Nuovo minimo di ripetizioni: il massimo lo segue se resta sotto.
    public static func settingMin(_ newMin: Int, max: Int) -> (min: Int, max: Int) {
        let low = clamp(newMin, reps)
        return (low, Swift.max(max, low))
    }

    /// Nuovo massimo di ripetizioni: il minimo lo segue se resta sopra.
    public static func settingMax(_ newMax: Int, min: Int) -> (min: Int, max: Int) {
        let high = clamp(newMax, reps)
        return (Swift.min(min, high), high)
    }

    public static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }

    public static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }
}

/// Riassunto di un esercizio nella scheda: «3 set da 8 a 12, 2 avvicinamenti, recupero 2:30».
public enum EntrySummary {
    public static func text(sets: Int, repsMin: Int, repsMax: Int, approaches: Int, fixedRest: Double?) -> String {
        let reps = repsMin == repsMax ? "da \(repsMin)" : "da \(repsMin) a \(repsMax)"
        var parts = ["\(sets) set \(reps)"]
        if approaches == 1 {
            parts.append("1 avvicinamento")
        } else if approaches > 1 {
            parts.append("\(approaches) avvicinamenti")
        }
        if let fixedRest {
            parts.append("recupero \(Clock.text(fixedRest))")
        }
        return parts.joined(separator: ", ")
    }
}

/// Testi di aiuto sotto i campi del foglio.
public enum EntryHints {
    /// «Al 50% e al 75% del peso di lavoro di oggi.»; `nil` senza avvicinamento.
    public static func approach(count: Int) -> String? {
        let percents = Approach.percentages(count: count).map { Int(($0 * 100).rounded()) }
        guard !percents.isEmpty else { return nil }
        let items = percents.map { "\(article($0)) \($0)%".replacingOccurrences(of: "' ", with: "'") }
        let list: String
        if items.count == 1 {
            list = items[0]
        } else {
            list = items.dropLast().joined(separator: ", ") + " e " + items[items.count - 1]
        }
        return list.prefix(1).uppercased() + list.dropFirst() + " del peso di lavoro di oggi."
    }

    /// «Quando arrivi a 12 in tutti i set, la volta dopo l'app propone +2,5 kg.»
    public static func progression(repsMax: Int, step: Double, unit: String = "kg") -> String {
        "Quando arrivi a \(repsMax) in tutti i set, la volta dopo l'app propone +\(Weights.format(step)) \(unit)."
    }

    /// «al 60%», «all'80%», «all'11%».
    static func article(_ percent: Int) -> String {
        let text = String(percent)
        return text.hasPrefix("8") || text.hasPrefix("11") ? "all'" : "al"
    }
}

/// Giorni del piano in cui c'è una scheda: «Lunedì e giovedì».
public enum PlanDaysText {
    public static func list(_ weekdays: [Int], capitalized: Bool = true) -> String? {
        let names = Set(weekdays).sorted().map { Weekday.name($0).lowercased() }.filter { !$0.isEmpty }
        guard let last = names.last else { return nil }
        let text = names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " e " + last
        return capitalized ? text.prefix(1).uppercased() + text.dropFirst() : text
    }
}

extension RoutineSummary {
    /// Riga sotto il nome nell'editor: «5 esercizi, 14 set, circa 55 minuti. Nel piano: lunedì e giovedì».
    public static func editorLine(_ entries: [Entry], weekdays: [Int], usualRest: Double? = nil) -> String {
        var text: String
        if entries.isEmpty {
            text = "Nessun esercizio"
        } else {
            let sets = entries.reduce(0) { $0 + $1.sets }
            let exercises = entries.count == 1 ? "1 esercizio" : "\(entries.count) esercizi"
            let setText = sets == 1 ? "1 set" : "\(sets) set"
            text = "\(exercises), \(setText), circa \(estimatedMinutes(entries, usualRest: usualRest)) minuti"
        }
        if let days = PlanDaysText.list(weekdays, capitalized: false) {
            text += ". Nel piano: \(days)"
        }
        return text
    }
}

/// Riordino con «tieni premuto per spostare» (stessa semantica di `move(fromOffsets:toOffset:)`).
public enum ListOrder {
    public static func move<Item>(_ items: [Item], from source: IndexSet, to destination: Int) -> [Item] {
        let moving = source.filter { items.indices.contains($0) }.map { items[$0] }
        var remaining: [Item] = []
        var insertAt = destination
        for (index, item) in items.enumerated() {
            if source.contains(index) {
                if index < destination { insertAt -= 1 }
            } else {
                remaining.append(item)
            }
        }
        insertAt = Swift.min(Swift.max(insertAt, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertAt)
        return remaining
    }
}

/// Nomi per le schede nuove e duplicate, senza doppioni.
public enum RoutineNames {
    public static func new(existing: [String]) -> String {
        unique("Nuova scheda", existing: existing)
    }

    public static func copy(of name: String, existing: [String]) -> String {
        let base = "\(name) (copia)"
        guard taken(base, in: existing) else { return base }
        var n = 2
        while taken("\(name) (copia \(n))", in: existing) { n += 1 }
        return "\(name) (copia \(n))"
    }

    static func unique(_ base: String, existing: [String]) -> String {
        guard taken(base, in: existing) else { return base }
        var n = 2
        while taken("\(base) \(n)", in: existing) { n += 1 }
        return "\(base) \(n)"
    }

    static func taken(_ name: String, in existing: [String]) -> Bool {
        existing.contains { LibrarySearch.fold($0) == LibrarySearch.fold(name) }
    }
}

/// Promemoria: salvati in un solo testo, uno per riga.
public enum Cues {
    public static func split(_ text: String) -> [String] {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public static func join(_ cues: [String]) -> String {
        cues.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// Passo dei dischi finché non c'è «Unità e dischi» nelle Impostazioni (settimana 4).
public enum PlateStep {
    public static let standard: Double = 2.5
}

extension SessionStats {
    /// Recupero abituale da durate già filtrate (recuperi dei set di lavoro, in ordine di tempo):
    /// media delle ultime `lastN`. `nil` se non ci sono dati.
    public static func usualRest(restDurations: [TimeInterval], lastN: Int = 20) -> TimeInterval? {
        let recent = restDurations.suffix(lastN)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    /// Arrotonda un recupero al passo dello stepper (15 s), dentro i limiti.
    public static func roundedRest(_ seconds: TimeInterval) -> TimeInterval {
        let step = EntryLimits.restStep
        return EntryLimits.clamp((seconds / step).rounded() * step, EntryLimits.rest)
    }
}
