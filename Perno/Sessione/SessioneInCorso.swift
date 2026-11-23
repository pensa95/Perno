import Foundation
import Observation
import SwiftData
import PernoCore

/// Sessione aperta: tiene la macchina a stati di `PernoCore` e a ogni tocco scrive nel registro
/// (set fatti, pause misurate, ultimo tocco), così niente si perde se l'app si chiude.
@Observable
final class SessioneInCorso: Identifiable {
    let sessione: WorkoutSession
    /// Esercizi nell'ordine della scheda (gli indici della macchina puntano qui).
    let esercizi: [SessionExercise]
    /// Set di ogni esercizio, avvicinamenti prima (stessi indici della macchina).
    let set: [[SessionSet]]
    /// Set di lavoro dell'ultima volta, per «prima 60 × 12».
    let prima: [[(weight: Double, reps: Int)]]
    /// Secondi del 3-2-1 (3, 5 o 10 dalle Impostazioni, che arrivano nella settimana 4).
    let secondiContoAllaRovescia = 3

    private(set) var macchina: SessionMachine
    /// Recupero abituale dell'esercizio corrente; aggiornato a ogni tocco.
    private(set) var recuperoAbituale: TimeInterval? = nil

    private let context: ModelContext
    private var setScritti = 0
    private var pauseScritte = 0

    let id: UUID

    init(sessione: WorkoutSession, riscaldamento: Bool = true, context: ModelContext) {
        self.sessione = sessione
        self.id = sessione.id
        self.context = context
        let esercizi = sessione.orderedExercises
        self.esercizi = esercizi
        let set = esercizi.map(\.orderedSets)
        self.set = set
        self.prima = esercizi.map { $0.exercise.map(WorkoutSession.ultimiSetDiLavoro) ?? [] }
        let piano = zip(esercizi, set).map { esercizio, sets in
            PlannedExercise(name: esercizio.name, sets: sets.map {
                PlannedSet(kind: $0.kind, weight: $0.targetWeight, reps: $0.targetReps)
            })
        }
        self.macchina = SessionMachine(exercises: piano, warmUp: riscaldamento, at: sessione.startedAt)
        aggiornaRecuperoAbituale()
    }

    // MARK: Lettura

    var fase: SessionPhase { macchina.phase }

    var esercizioCorrente: SessionExercise? {
        macchina.currentExerciseIndex.map { esercizi[$0] }
    }

    var setCorrente: SessionSet? {
        guard let indice = macchina.currentExerciseIndex, macchina.setIndex < set[indice].count else { return nil }
        return set[indice][macchina.setIndex]
    }

    /// Posizione dell'esercizio corrente nell'ordine di oggi (1…).
    var numeroEsercizio: Int { macchina.position + 1 }

    /// Numero del set corrente dentro il suo tipo («Avv. 2», «Set 1»).
    var numeroSetCorrente: Int {
        guard let indice = macchina.currentExerciseIndex else { return 1 }
        let numeri = SessionText.numbers(set[indice].map(\.kind))
        return macchina.setIndex < numeri.count ? numeri[macchina.setIndex] : 1
    }

    /// Esercizi nell'ordine di oggi (per «Poi, in ordine» del riscaldamento).
    var ordineDiOggi: [SessionExercise] { macchina.order.map { esercizi[$0] } }

    var puoRimandare: Bool {
        if case .changeover = fase, macchina.setIndex == 0, macchina.position < macchina.order.count - 1 {
            return true
        }
        return false
    }

    // MARK: Tocchi

    func riscaldamentoFatto(alle ora: Date = .now) { esegui(ora) { try $0.endWarmUp(at: ora) } }

    func inizia(alle ora: Date = .now) { esegui(ora) { try $0.start(at: ora) } }

    func annullaContoAllaRovescia() { esegui(.now) { try $0.cancelCountdown() } }

    func contoAllaRovesciaFinito(alle ora: Date) { esegui(ora) { try $0.countdownFinished(at: ora) } }

    func setFatto(alle ora: Date = .now) { esegui(ora) { try $0.setDone(at: ora) } }

    func rimanda() { esegui(.now) { try $0.postponeCurrent() } }

    /// «Concludi», o fine dell'ultimo set. Il riepilogo arriva nella settimana 4: per ora la
    /// sessione si chiude e va nello storico così com'è.
    func concludi(alle ora: Date = .now) {
        macchina.finish()
        sessione.endedAt = sessione.endedAt ?? ora
        sessione.isSaved = true
        sessione.lastActivityAt = ora
        try? context.save()
    }

    private func esegui(_ ora: Date, _ azione: (inout SessionMachine) throws -> Void) {
        let ordinePrima = macchina.order
        do {
            try azione(&macchina)
        } catch {
            return
        }
        scriviNelRegistro(ora: ora, ordinePrima: ordinePrima)
        if macchina.phase == .finished {
            concludi(alle: ora)
        }
    }

    // MARK: Registro

    private func scriviNelRegistro(ora: Date, ordinePrima: [Int]) {
        for fatto in macchina.completedSets.dropFirst(setScritti) {
            let registrato = set[fatto.exerciseIndex][fatto.setIndex]
            registrato.weight = fatto.weight
            registrato.reps = fatto.reps
            registrato.startedAt = fatto.startedAt
            registrato.endedAt = fatto.endedAt
        }
        setScritti = macchina.completedSets.count

        for pausa in macchina.pauses.dropFirst(pauseScritte) {
            let registrata = SessionPause(kind: pausa.kind,
                                          sessionExercise: pausa.exerciseIndex.map { esercizi[$0] },
                                          afterApproach: pausa.afterApproach,
                                          start: pausa.start, end: pausa.end)
            context.insert(registrata)
            registrata.session = sessione
        }
        pauseScritte = macchina.pauses.count

        if macchina.order != ordinePrima {
            for (posizione, indice) in macchina.order.enumerated() {
                esercizi[indice].position = posizione
            }
            if let rimandato = ordinePrima[safe: macchina.position] {
                esercizi[rimandato].isPostponed = true
            }
        }

        sessione.lastActivityAt = ora
        aggiornaRecuperoAbituale()
        try? context.save()
    }

    /// Media dei recuperi dei set di lavoro di questo esercizio (sessioni passate e di oggi).
    private func aggiornaRecuperoAbituale() {
        guard let esercizio = esercizioCorrente?.exercise else {
            recuperoAbituale = nil
            return
        }
        let pause = esercizio.sessionExercises
            .flatMap(\.pauses)
            .filter { $0.kind == .rest }
            .sorted { $0.start < $1.start }
            .map { Pause(kind: $0.kind, exerciseIndex: nil, afterApproach: $0.afterApproach,
                         start: $0.start, end: $0.end) }
        recuperoAbituale = SessionStats.usualRest(pause)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
