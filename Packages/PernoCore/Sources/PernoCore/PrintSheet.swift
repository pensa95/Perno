import Foundation

// Foglio da stampare (PDF) di una sessione o di una scheda, con lo stesso formato: intestazione,
// esercizi numerati con riassunto, regolazioni e promemoria, tabella dei set (Set, Obiettivo, Peso,
// Ripetizioni, Riserva), nota e piè di pagina. Per la scheda le ultime tre colonne restano vuote,
// da compilare a penna; per la sessione contengono i valori fatti.

public struct PrintSheet: Equatable, Sendable {
    /// Occhiello sopra il titolo: «Sessione» o «Scheda».
    public var kind: String
    public var title: String
    /// Righe sotto il titolo (data e numeri per la sessione, riassunto e giorni per la scheda).
    public var lines: [String]
    public var exercises: [PrintExercise]
    public var note: String?
    public var footer: String

    public init(kind: String, title: String, lines: [String], exercises: [PrintExercise],
                note: String?, footer: String) {
        self.kind = kind
        self.title = title
        self.lines = lines
        self.exercises = exercises
        self.note = note
        self.footer = footer
    }

    /// Intestazioni delle colonne della tabella dei set.
    public static func columns(unit: String) -> [String] {
        ["Set", "Obiettivo", "Peso (\(unit))", "Ripetizioni", "Riserva"]
    }
}

public struct PrintExercise: Equatable, Sendable {
    public var number: Int
    public var name: String
    /// «3 set da 8 a 12, 1 avvicinamento, recupero 2:00».
    public var detail: String
    public var setup: String?
    public var cues: [String]
    public var note: String?
    public var rows: [PrintRow]

    public init(number: Int, name: String, detail: String, setup: String?, cues: [String],
                note: String?, rows: [PrintRow]) {
        self.number = number
        self.name = name
        self.detail = detail
        self.setup = setup
        self.cues = cues
        self.note = note
        self.rows = rows
    }
}

public struct PrintRow: Equatable, Sendable {
    /// «Avv. 1», «Set 2».
    public var label: String
    /// «60%» per gli avvicinamenti, «8–12» per i set.
    public var target: String
    public var weight: String
    public var reps: String
    public var reserve: String
    /// Avvicinamento (riga più chiara).
    public var isApproach: Bool

    public init(label: String, target: String, weight: String, reps: String, reserve: String, isApproach: Bool) {
        self.label = label
        self.target = target
        self.weight = weight
        self.reps = reps
        self.reserve = reserve
        self.isApproach = isApproach
    }
}

/// Testi del foglio da stampare.
public enum PrintText {
    /// «8–12», oppure «8» se minimo e massimo coincidono.
    public static func repsTarget(min: Int, max: Int) -> String {
        min == max ? "\(min)" : "\(min)–\(max)"
    }

    /// «60%».
    public static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// Obiettivi di un esercizio: avvicinamenti in percentuale, poi i set con le ripetizioni.
    public static func targets(sets: Int, repsMin: Int, repsMax: Int, approaches: Int) -> [(label: String, target: String, isApproach: Bool)] {
        let percents = Approach.percentages(count: approaches)
        var rows = percents.enumerated().map { index, fraction in
            (label: SessionText.shortName(.approach, index + 1), target: percent(fraction), isApproach: true)
        }
        for index in 0..<max(0, sets) {
            rows.append((label: SessionText.shortName(.work, index + 1),
                         target: repsTarget(min: repsMin, max: repsMax), isApproach: false))
        }
        return rows
    }

    /// Righe vuote della scheda: Peso, Ripetizioni e Riserva da compilare a penna.
    public static func routineRows(sets: Int, repsMin: Int, repsMax: Int, approaches: Int) -> [PrintRow] {
        targets(sets: sets, repsMin: repsMin, repsMax: repsMax, approaches: approaches).map {
            PrintRow(label: $0.label, target: $0.target, weight: "", reps: "", reserve: "", isApproach: $0.isApproach)
        }
    }

    /// Riga di un set della sessione. `weight` è già nell'unità in uso; set non fatto: «—».
    public static func sessionRow(kind: SetKind, number: Int, target: String, done: Bool,
                                  weight: String?, reps: Int?, reserve: Reserve?) -> PrintRow {
        PrintRow(label: SessionText.shortName(kind, number),
                 target: target,
                 weight: done ? (weight ?? "—") : "—",
                 reps: done ? (reps.map(String.init) ?? "—") : "—",
                 reserve: done ? (reserve?.label ?? "") : "",
                 isApproach: kind == .approach)
    }

    /// Righe sotto il titolo della sessione: quando, poi durata, set e peso sollevato.
    public static func sessionLines(when: String, duration: String, setsDone: Int, setsPlanned: Int,
                                    volume: String, unit: String) -> [String] {
        [when, "Durata \(duration) · \(setsDone)/\(setsPlanned) set · \(volume) \(unit) sollevati"]
    }

    /// «Perno · esportato il 24 novembre 2026».
    public static func footer(exportedAt date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        let month = ItalianDate.months[max(0, min(11, (parts.month ?? 1) - 1))]
        return "Perno · esportato il \(parts.day ?? 1) \(month) \(parts.year ?? 2026)"
    }

    /// Nome del file: «Upper body 24-11-2026.pdf» (senza caratteri non validi nei nomi dei file).
    public static func fileName(title: String, date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        let cleaned = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleaned.isEmpty ? "Perno" : cleaned
        return "\(name) \(two(parts.day ?? 1))-\(two(parts.month ?? 1))-\(parts.year ?? 2026).pdf"
    }
}
