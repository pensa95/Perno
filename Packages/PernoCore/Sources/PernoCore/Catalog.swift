import Foundation

// MARK: - Classificazione degli esercizi

/// Gruppo muscolare. Il valore grezzo è quello salvato: non cambiarlo.
public enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest
    case back
    case shoulders
    case legs
    case arms
    case abs

    public var label: String {
        switch self {
        case .chest: return "Petto"
        case .back: return "Schiena"
        case .shoulders: return "Spalle"
        case .legs: return "Gambe"
        case .arms: return "Braccia"
        case .abs: return "Addome"
        }
    }
}

/// Attrezzo. Il valore grezzo è quello salvato: non cambiarlo.
public enum Equipment: String, CaseIterable, Codable, Sendable {
    case machine
    case cable
    case barbell
    case dumbbell
    case bodyweight
    case other

    public var label: String {
        switch self {
        case .machine: return "Macchina"
        case .cable: return "Cavi"
        case .barbell: return "Bilanciere"
        case .dumbbell: return "Manubri"
        case .bodyweight: return "Corpo libero"
        case .other: return "Altro"
        }
    }
}

/// Tipo di esercizio. Nella v1 si usa solo `weights`; gli altri sono già nel modello dati.
public enum ExerciseType: String, CaseIterable, Codable, Sendable {
    case weights
    case bodyweight
    case timed

    public var label: String {
        switch self {
        case .weights: return "Pesi"
        case .bodyweight: return "Corpo libero"
        case .timed: return "A tempo"
        }
    }
}

// MARK: - Set

extension SetKind {
    public var label: String {
        switch self {
        case .approach: return "Avvicinamento"
        case .work: return "Normale"
        case .drop: return "Drop set"
        case .failure: return "A cedimento"
        }
    }
}

/// Riserva: ripetizioni che restavano (sostituisce l'RPE). Salvata come intero 0…4.
public enum Reserve: Int, CaseIterable, Codable, Sendable {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
    case fourOrMore = 4

    public var label: String {
        self == .fourOrMore ? "4+" : String(rawValue)
    }
}

// MARK: - Settimana

/// Giorni del piano settimanale: 1 = lunedì … 7 = domenica.
public enum Weekday {
    public static let all = Array(1...7)

    /// Giorno della settimana di `date` nel calendario dato (lunedì = 1).
    public static func of(_ date: Date, calendar: Calendar = .current) -> Int {
        // Nel calendario gregoriano `weekday` va da 1 (domenica) a 7 (sabato).
        let gregorian = calendar.component(.weekday, from: date)
        return (gregorian + 5) % 7 + 1
    }
}

// MARK: - Libreria precaricata

public struct LibraryEntry: Equatable, Sendable {
    /// Identificativo stabile dell'esercizio precaricato (per seed e backup).
    public var key: String
    public var name: String
    public var group: MuscleGroup
    public var equipment: Equipment
    public var type: ExerciseType

    public init(key: String, name: String, group: MuscleGroup, equipment: Equipment,
                type: ExerciseType = .weights) {
        self.key = key
        self.name = name
        self.group = group
        self.equipment = equipment
        self.type = type
    }
}

public enum ExerciseLibrary {
    /// Esercizi precaricati al primo avvio; l'utente li può modificare.
    public static let builtIn: [LibraryEntry] = [
        // Petto
        LibraryEntry(key: "panca-piana-bilanciere", name: "Panca piana con bilanciere", group: .chest, equipment: .barbell),
        LibraryEntry(key: "panca-inclinata-manubri", name: "Panca inclinata con manubri", group: .chest, equipment: .dumbbell),
        LibraryEntry(key: "panca-piana-manubri", name: "Panca piana con manubri", group: .chest, equipment: .dumbbell),
        LibraryEntry(key: "chest-press", name: "Chest press", group: .chest, equipment: .machine),
        LibraryEntry(key: "pectoral-machine", name: "Pectoral machine", group: .chest, equipment: .machine),
        LibraryEntry(key: "croci-cavi", name: "Croci ai cavi", group: .chest, equipment: .cable),
        LibraryEntry(key: "dip-parallele", name: "Dip alle parallele", group: .chest, equipment: .bodyweight),
        // Schiena
        LibraryEntry(key: "lat-machine", name: "Lat machine", group: .back, equipment: .machine),
        LibraryEntry(key: "pulley-basso", name: "Pulley basso", group: .back, equipment: .cable),
        LibraryEntry(key: "low-row", name: "Low row", group: .back, equipment: .machine),
        LibraryEntry(key: "rematore-bilanciere", name: "Rematore con bilanciere", group: .back, equipment: .barbell),
        LibraryEntry(key: "rematore-manubrio", name: "Rematore con manubrio", group: .back, equipment: .dumbbell),
        LibraryEntry(key: "trazioni", name: "Trazioni alla sbarra", group: .back, equipment: .bodyweight),
        LibraryEntry(key: "pulldown-braccia-tese", name: "Pulldown a braccia tese", group: .back, equipment: .cable),
        LibraryEntry(key: "stacco-da-terra", name: "Stacco da terra", group: .back, equipment: .barbell),
        // Spalle
        LibraryEntry(key: "military-press", name: "Military press", group: .shoulders, equipment: .barbell),
        LibraryEntry(key: "shoulder-press", name: "Shoulder press", group: .shoulders, equipment: .machine),
        LibraryEntry(key: "lento-manubri", name: "Lento con manubri", group: .shoulders, equipment: .dumbbell),
        LibraryEntry(key: "alzate-laterali-manubri", name: "Alzate laterali con manubri", group: .shoulders, equipment: .dumbbell),
        LibraryEntry(key: "alzate-laterali-cavi", name: "Alzate laterali ai cavi", group: .shoulders, equipment: .cable),
        LibraryEntry(key: "face-pull", name: "Face pull", group: .shoulders, equipment: .cable),
        LibraryEntry(key: "reverse-fly", name: "Reverse fly", group: .shoulders, equipment: .machine),
        // Gambe
        LibraryEntry(key: "squat-bilanciere", name: "Squat con bilanciere", group: .legs, equipment: .barbell),
        LibraryEntry(key: "leg-press", name: "Leg press", group: .legs, equipment: .machine),
        LibraryEntry(key: "hack-squat", name: "Hack squat", group: .legs, equipment: .machine),
        LibraryEntry(key: "leg-extension", name: "Leg extension", group: .legs, equipment: .machine),
        LibraryEntry(key: "leg-curl", name: "Leg curl", group: .legs, equipment: .machine),
        LibraryEntry(key: "affondi-manubri", name: "Affondi con manubri", group: .legs, equipment: .dumbbell),
        LibraryEntry(key: "split-squat-bulgaro", name: "Split squat bulgaro", group: .legs, equipment: .dumbbell),
        LibraryEntry(key: "stacco-rumeno", name: "Stacco rumeno", group: .legs, equipment: .barbell),
        LibraryEntry(key: "hip-thrust", name: "Hip thrust", group: .legs, equipment: .barbell),
        LibraryEntry(key: "abductor-machine", name: "Abductor machine", group: .legs, equipment: .machine),
        LibraryEntry(key: "adductor-machine", name: "Adductor machine", group: .legs, equipment: .machine),
        LibraryEntry(key: "calf-in-piedi", name: "Calf in piedi", group: .legs, equipment: .machine),
        // Braccia
        LibraryEntry(key: "curl-bilanciere", name: "Curl con bilanciere", group: .arms, equipment: .barbell),
        LibraryEntry(key: "curl-manubri", name: "Curl con manubri", group: .arms, equipment: .dumbbell),
        LibraryEntry(key: "curl-martello", name: "Curl a martello", group: .arms, equipment: .dumbbell),
        LibraryEntry(key: "curl-cavi", name: "Curl ai cavi", group: .arms, equipment: .cable),
        LibraryEntry(key: "french-press", name: "French press", group: .arms, equipment: .barbell),
        LibraryEntry(key: "pushdown-cavi", name: "Pushdown ai cavi", group: .arms, equipment: .cable),
        LibraryEntry(key: "estensioni-sopra-testa-cavi", name: "Estensioni sopra la testa ai cavi", group: .arms, equipment: .cable),
        // Addome
        LibraryEntry(key: "crunch-cavi", name: "Crunch ai cavi", group: .abs, equipment: .cable),
        LibraryEntry(key: "ab-crunch-machine", name: "Ab crunch machine", group: .abs, equipment: .machine),
        LibraryEntry(key: "crunch", name: "Crunch", group: .abs, equipment: .bodyweight),
        LibraryEntry(key: "sollevamento-gambe", name: "Sollevamento gambe alla sbarra", group: .abs, equipment: .bodyweight),
    ]
}
