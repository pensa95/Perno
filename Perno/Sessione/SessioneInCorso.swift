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
    /// Avviso dopo «Set fatto» (ripetizioni, riserva, Annulla); `nil` quando è chiuso.
    private(set) var avviso: Avviso? = nil
    /// Secondi in cui l'avviso resta aperto; ogni tocco li rinnova.
    static let durataAvviso: TimeInterval = 5

    struct Avviso: Equatable {
        let esercizio: Int
        let set: Int
        var scadenza: Date
    }

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

    /// Esercizio sullo schermo: quello corrente; a sessione finita, quello dell'ultimo avviso.
    var indiceEsercizio: Int? {
        macchina.currentExerciseIndex ?? avviso?.esercizio
    }

    var esercizioCorrente: SessionExercise? {
        indiceEsercizio.map { esercizi[$0] }
    }

    /// Vero quando la sessione è chiusa: la schermata si chiude.
    private(set) var conclusa = false

    var setCorrente: SessionSet? {
        guard let indice = macchina.currentExerciseIndex, macchina.setIndex < set[indice].count else { return nil }
        return set[indice][macchina.setIndex]
    }

    /// Posizione dell'esercizio corrente nell'ordine di oggi (1…).
    var numeroEsercizio: Int { min(macchina.position + 1, macchina.order.count) }

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

    func inizia(alle ora: Date = .now) {
        avviso = nil
        esegui(ora) { try $0.start(at: ora) }
    }

    func annullaContoAllaRovescia() { esegui(.now) { try $0.cancelCountdown() } }

    func contoAllaRovesciaFinito(alle ora: Date) { esegui(ora) { try $0.countdownFinished(at: ora) } }

    func setFatto(alle ora: Date = .now) {
        let fattiPrima = macchina.completedSets.count
        esegui(ora) { try $0.setDone(at: ora) }
        if let fatto = macchina.completedSets.last, macchina.completedSets.count > fattiPrima {
            avviso = Avviso(esercizio: fatto.exerciseIndex, set: fatto.setIndex,
                            scadenza: ora.addingTimeInterval(Self.durataAvviso))
        }
    }

    // MARK: Correggi set

    /// «Salva» in Correggi set. Su un set fatto corregge i valori registrati; su un set da fare
    /// (anche quello di adesso) cambia l'obiettivo. I set dopo con lo stesso obiettivo prendono il
    /// peso nuovo (e, dal primo set di lavoro, anche gli avvicinamenti da fare).
    func correggi(esercizio: Int, set indice: Int, peso: Double, ripetizioni: Int,
                  tipo: SetKind, riserva: Reserve?, alle ora: Date = .now) {
        let registrato = set[esercizio][indice]
        let cambiati: [Int]
        do {
            if macchina.isDone(exercise: esercizio, set: indice) {
                cambiati = try macchina.correctSet(exercise: esercizio, set: indice, weight: peso,
                                                   reps: ripetizioni, kind: tipo)
            } else {
                cambiati = try macchina.retargetSet(exercise: esercizio, set: indice, weight: peso,
                                                    reps: ripetizioni, kind: tipo, step: PlateStep.standard)
            }
        } catch {
            return
        }
        if let fatto = macchina.completedSets.first(where: { $0.exerciseIndex == esercizio && $0.setIndex == indice }) {
            registrato.weight = fatto.weight
            registrato.reps = fatto.reps
            registrato.kind = fatto.kind
            registrato.reserve = riserva
        }
        for cambiato in cambiati {
            let piano = macchina.exercises[esercizio].sets[cambiato]
            let daAggiornare = set[esercizio][cambiato]
            daAggiornare.targetWeight = piano.weight
            daAggiornare.targetReps = piano.reps
            daAggiornare.kind = piano.kind
        }
        sessione.lastActivityAt = ora
        try? context.save()
    }

    /// «Elimina set»: il set torna non fatto.
    func eliminaSet(esercizio: Int, set indice: Int, alle ora: Date = .now) {
        do {
            try macchina.removeSet(exercise: esercizio, set: indice)
        } catch {
            return
        }
        let registrato = set[esercizio][indice]
        registrato.weight = nil
        registrato.reps = nil
        registrato.reserve = nil
        registrato.startedAt = nil
        registrato.endedAt = nil
        setScritti = macchina.completedSets.count
        if avviso?.esercizio == esercizio && avviso?.set == indice {
            avviso = nil
        }
        sessione.lastActivityAt = ora
        try? context.save()
    }

    // MARK: Avviso dopo «Set fatto»

    /// Set dell'avviso, con i valori registrati.
    var setDellAvviso: SessionSet? {
        avviso.map { set[$0.esercizio][$0.set] }
    }

    /// −/+ sulle ripetizioni del set appena fatto.
    func cambiaRipetizioni(di passo: Int, alle ora: Date = .now) {
        guard let registrato = setDellAvviso, let attuali = registrato.reps else { return }
        do {
            try macchina.correctLastSet(reps: attuali + passo)
        } catch {
            return
        }
        registrato.reps = macchina.completedSets.last?.reps
        rinnovaAvviso(ora)
    }

    /// «Quante ne avevi ancora?»: un secondo tocco sullo stesso valore lo toglie.
    func scegliRiserva(_ riserva: Reserve, alle ora: Date = .now) {
        guard let registrato = setDellAvviso else { return }
        registrato.reserve = registrato.reserve == riserva ? nil : riserva
        rinnovaAvviso(ora)
    }

    /// «Annulla»: il set torna in corso, con il cronometro di prima.
    func annullaSetFatto(alle ora: Date = .now) {
        guard let registrato = setDellAvviso else { return }
        do {
            try macchina.undoLastSet()
        } catch {
            return
        }
        registrato.weight = nil
        registrato.reps = nil
        registrato.reserve = nil
        registrato.startedAt = nil
        registrato.endedAt = nil
        setScritti = macchina.completedSets.count
        avviso = nil
        sessione.lastActivityAt = ora
        aggiornaRecuperoAbituale()
        try? context.save()
    }

    /// Fine dei 5 s senza tocchi.
    func chiudiAvviso() {
        avviso = nil
        if macchina.phase == .finished {
            concludi()
        }
    }

    private func rinnovaAvviso(_ ora: Date) {
        avviso?.scadenza = ora.addingTimeInterval(Self.durataAvviso)
        sessione.lastActivityAt = ora
        try? context.save()
    }

    func rimanda() { esegui(.now) { try $0.postponeCurrent() } }

    /// «Concludi», o fine dell'ultimo set (quando si chiude il suo avviso). Il riepilogo arriva nella settimana 4: per ora la
    /// sessione si chiude e va nello storico così com'è.
    func concludi(alle ora: Date = .now) {
        macchina.finish()
        avviso = nil
        conclusa = true
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
