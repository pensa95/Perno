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
    private(set) var esercizi: [SessionExercise]
    /// Set di ogni esercizio, avvicinamenti prima (stessi indici della macchina).
    private(set) var set: [[SessionSet]]
    /// Set di lavoro dell'ultima volta, per «prima 60 × 12».
    private(set) var prima: [[(weight: Double, reps: Int)]]
    /// Set a tempo dell'ultima volta, per «prima 10 × 0:40» e «+5 s» (UI v5).
    private(set) var primaATempo: [[TimedSet]]
    /// Secondi del 3-2-1 (3, 5 o 10 dalle Impostazioni, «Prima di ogni set»).
    let secondiContoAllaRovescia = Impostazioni.secondiContoAllaRovescia

    private(set) var macchina: SessionMachine
    /// Recupero abituale dell'esercizio corrente; aggiornato a ogni tocco.
    private(set) var recuperoAbituale: TimeInterval? = nil
    /// Avviso dopo «Set fatto» (ripetizioni, riserva, Annulla); `nil` quando è chiuso.
    private(set) var avviso: Avviso? = nil
    /// Secondi in cui l'avviso resta aperto; ogni tocco li rinnova.
    static let durataAvviso: TimeInterval = 5

    /// Recupero in cronometro o alla rovescia: l'ultima scelta resta (anche tra le sessioni).
    var modoRecupero: RestMode {
        didSet { UserDefaults.standard.set(modoRecupero.rawValue, forKey: Self.chiaveModoRecupero) }
    }
    private static let chiaveModoRecupero = Impostazioni.modoRecupero
    /// Secondi aggiunti con «+15 s» al recupero che inizia in `inizio`.
    private var aggiunta: (inizio: Date, secondi: TimeInterval)? = nil

    struct Avviso: Equatable {
        let esercizio: Int
        let set: Int
        var scadenza: Date
    }

    private let context: ModelContext
    /// Orario di «Rimanda» per esercizio (per «Macchinario occupato alle 18:20» nella scaletta).
    private(set) var rimandatiAlle: [Int: Date] = [:]
    private var setScritti = 0
    private var pauseScritte = 0

    let id: UUID

    /// `riprendi`: sessione interrotta (app chiusa) che riparte dal set dopo l'ultimo «Set fatto»,
    /// con il recupero ricalcolato da adesso.
    init(sessione: WorkoutSession, riscaldamento: Bool = true, riprendi: Bool = false,
         alle ora: Date = .now, context: ModelContext) {
        self.sessione = sessione
        self.id = sessione.id
        self.context = context
        let esercizi = sessione.orderedExercises
        self.esercizi = esercizi
        let set = esercizi.map(\.orderedSets)
        self.set = set
        self.prima = esercizi.map { $0.exercise.map(WorkoutSession.ultimiSetDiLavoro) ?? [] }
        self.primaATempo = esercizi.map { voce in
            voce.isTimed ? (voce.exercise.map(WorkoutSession.ultimiSetATempo) ?? []) : []
        }
        let piano = zip(esercizi, set).map { esercizio, sets in
            PlannedExercise(name: esercizio.name, sets: sets.map {
                PlannedSet(kind: $0.kind, weight: $0.targetWeight, reps: $0.targetReps)
            })
        }
        if riprendi {
            var fatti: [CompletedSet] = []
            for (esercizio, sets) in set.enumerated() {
                for (indice, registrato) in sets.enumerated() {
                    guard let fine = registrato.endedAt, let peso = registrato.weight,
                          let ripetizioni = registrato.reps else { continue }
                    fatti.append(CompletedSet(exerciseIndex: esercizio, setIndex: indice, kind: registrato.kind,
                                              weight: peso, reps: ripetizioni,
                                              startedAt: registrato.startedAt ?? fine, endedAt: fine))
                }
            }
            let pause = sessione.orderedPauses.map { pausa in
                Pause(kind: pausa.kind,
                      exerciseIndex: esercizi.firstIndex { $0 === pausa.sessionExercise },
                      afterApproach: pausa.afterApproach, start: pausa.start, end: pausa.end)
            }
            self.macchina = SessionMachine(resuming: piano, completed: fatti, pauses: pause,
                                           openEnded: sessione.isFree, at: ora)
            sessione.lastActivityAt = ora
        } else if sessione.isFree {
            self.macchina = SessionMachine(openEndedAt: sessione.startedAt, warmUp: riscaldamento)
        } else {
            self.macchina = SessionMachine(exercises: piano, warmUp: riscaldamento, at: sessione.startedAt)
        }
        self.modoRecupero = UserDefaults.standard.string(forKey: Self.chiaveModoRecupero)
            .flatMap(RestMode.init(rawValue:)) ?? .stopwatch
        // Quello che è già nel registro non va riscritto.
        setScritti = macchina.completedSets.count
        pauseScritte = macchina.pauses.count
        aggiornaRecuperoAbituale()
    }

    // MARK: Lettura

    var fase: SessionPhase { macchina.phase }

    /// Esercizio sullo schermo: quello corrente; a sessione finita, quello dell'ultimo avviso o
    /// dell'ultimo set fatto («Continua» dal riepilogo dopo l'ultimo set).
    var indiceEsercizio: Int? {
        macchina.currentExerciseIndex ?? avviso?.esercizio ?? macchina.completedSets.last?.exerciseIndex
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
            if esercizi[fatto.exerciseIndex].isTimed {
                // A tempo: si salva il tempo fatto, mai oltre l'obiettivo (a zero si chiude da solo).
                let registrato = set[fatto.exerciseIndex][fatto.setIndex]
                registrato.seconds = TimedText.secondsDone(duration: fatto.duration,
                                                           target: obiettivoSecondi(registrato))
                try? context.save()
            }
            avviso = Avviso(esercizio: fatto.exerciseIndex, set: fatto.setIndex,
                            scadenza: ora.addingTimeInterval(Self.durataAvviso))
        }
    }

    // MARK: Set a tempo (UI v5)

    /// L'esercizio si misura a tempo.
    func aTempo(_ indice: Int) -> Bool {
        esercizi.indices.contains(indice) && esercizi[indice].isTimed
    }

    /// Durata obiettivo di un set a tempo, in secondi.
    func obiettivoSecondi(_ registrato: SessionSet) -> Int {
        registrato.targetSeconds ?? registrato.sessionExercise?.targetSeconds ?? DurationLimits.standard
    }

    /// Peso da mostrare per un esercizio a tempo: `nil` senza «Con peso».
    func pesoATempo(_ indice: Int, _ peso: Double) -> Double? {
        esercizi[indice].withWeight ? peso : nil
    }

    /// Dopo «Annulla» su un set a tempo già allo zero non si richiude da solo: si chiude a mano.
    @ObservationIgnored private var chiusuraSospesaDal: Date? = nil

    /// Zero del set a tempo in corso: lì il set si chiude da solo.
    var fineSetATempo: Date? {
        guard case let .inSet(dal) = fase, let indice = macchina.currentExerciseIndex, aTempo(indice),
              let registrato = setCorrente, chiusuraSospesaDal != dal else { return nil }
        return dal.addingTimeInterval(TimeInterval(obiettivoSecondi(registrato)))
    }

    /// −/+ di 5 s sulla durata del set a tempo appena fatto.
    func cambiaSecondi(di passi: Int, alle ora: Date = .now) {
        guard let registrato = setDellAvviso else { return }
        let attuali = registrato.seconds ?? obiettivoSecondi(registrato)
        registrato.seconds = DurationLimits.stepped(attuali, by: passi)
        rinnovaAvviso(ora)
    }

    // MARK: Recupero

    /// Durata del conto alla rovescia del recupero in corso (fissato, abituale o 2:00, più i «+15 s»).
    var durataRecupero: TimeInterval {
        let base = RestTimer.duration(fixed: esercizioCorrente?.fixedRest, usual: recuperoAbituale)
        guard case let .rest(dal) = fase, let aggiunta, aggiunta.inizio == dal else { return base }
        return base + aggiunta.secondi
    }

    var etichettaRecupero: String {
        RestTimer.label(fixed: esercizioCorrente?.fixedRest, usual: recuperoAbituale)
    }

    /// Tocco sul tempo: cronometro ↔ conto alla rovescia.
    func cambiaModoRecupero() {
        modoRecupero = modoRecupero.toggled
    }

    /// «+15 s» (solo nel conto alla rovescia): allunga il recupero in corso.
    func aggiungiQuindiciSecondi() {
        guard case let .rest(dal) = fase else { return }
        let gia = aggiunta?.inizio == dal ? (aggiunta?.secondi ?? 0) : 0
        aggiunta = (dal, gia + RestTimer.extraStep)
    }

    // MARK: Correggi set

    /// «Salva» in Correggi set. Su un set fatto corregge i valori registrati; su un set da fare
    /// (anche quello di adesso) cambia l'obiettivo. I set dopo con lo stesso obiettivo prendono il
    /// peso nuovo (e, dal primo set di lavoro, anche gli avvicinamenti da fare).
    func correggi(esercizio: Int, set indice: Int, peso: Double, ripetizioni: Int,
                  tipo: SetKind, riserva: Reserve?, secondi: Int? = nil, alle ora: Date = .now) {
        let registrato = set[esercizio][indice]
        if let secondi {
            // A tempo: durata fatta su un set fatto, durata obiettivo su un set da fare.
            if macchina.isDone(exercise: esercizio, set: indice) {
                registrato.seconds = secondi
            } else {
                registrato.targetSeconds = secondi
            }
        }
        let cambiati: [Int]
        do {
            if macchina.isDone(exercise: esercizio, set: indice) {
                cambiati = try macchina.correctSet(exercise: esercizio, set: indice, weight: peso,
                                                   reps: ripetizioni, kind: tipo)
            } else {
                cambiati = try macchina.retargetSet(exercise: esercizio, set: indice, weight: peso,
                                                    reps: ripetizioni, kind: tipo, step: PlateStep.current)
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
        registrato.seconds = nil
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
        registrato.seconds = nil
        setScritti = macchina.completedSets.count
        avviso = nil
        if case let .inSet(dal) = fase, let indice = macchina.currentExerciseIndex, aTempo(indice) {
            chiusuraSospesaDal = dal
        }
        sessione.lastActivityAt = ora
        aggiornaRecuperoAbituale()
        try? context.save()
    }

    /// Fine dei 5 s senza tocchi. Dopo l'ultimo set della sessione si apre il riepilogo, con la
    /// durata che finisce all'ultimo set.
    func chiudiAvviso() {
        avviso = nil
        if macchina.phase == .finished {
            apriRiepilogo(alle: macchina.completedSets.map(\.endedAt).max() ?? .now)
        }
    }

    private func rinnovaAvviso(_ ora: Date) {
        avviso?.scadenza = ora.addingTimeInterval(Self.durataAvviso)
        sessione.lastActivityAt = ora
        try? context.save()
    }

    func rimanda(alle ora: Date = .now) {
        let corrente = macchina.currentExerciseIndex
        esegui(ora) { try $0.postponeCurrent() }
        if let corrente, esercizi[corrente].isPostponed {
            rimandatiAlle[corrente] = ora
        }
    }

    // MARK: Sessione libera e Aggiungi esercizi

    /// Durata del riscaldamento fatto (per «Riscaldamento fatto, 6 minuti»).
    var durataRiscaldamento: TimeInterval? {
        macchina.pauses.first { $0.kind == .warmUp }?.duration
    }

    /// Cambio esercizio senza esercizio da fare: si sceglie il prossimo («Scegli esercizi»).
    var daScegliere: Bool {
        if case .changeover = fase, macchina.currentExerciseIndex == nil { return true }
        return false
    }

    /// «Aggiungi esercizi» (solo per oggi): in fondo all'ordine di oggi, 3 set da 8 a 12 senza
    /// avvicinamenti, obiettivi dalla volta precedente. La scheda non cambia.
    func aggiungi(_ nuovi: [Exercise], alle ora: Date = .now) {
        guard !nuovi.isEmpty else { return }
        var piani: [PlannedExercise] = []
        for esercizio in nuovi {
            let precedenti = WorkoutSession.ultimiSetDiLavoro(esercizio)
            let registrato = SessionExercise(position: esercizi.count, exercise: esercizio, name: esercizio.name,
                                             repsMin: FreeSessionText.addedRepsMin,
                                             repsMax: FreeSessionText.addedRepsMax)
            context.insert(registrato)
            registrato.session = sessione
            let piano = SessionPlanner.plan(workSets: FreeSessionText.addedSets, repsMin: FreeSessionText.addedRepsMin,
                                            repsMax: FreeSessionText.addedRepsMax, approaches: 0,
                                            history: WorkoutSession.storiaSetDiLavoro(esercizio),
                                            step: PlateStep.current)
            var sets: [SessionSet] = []
            for (posizione, pianificato) in piano.enumerated() {
                let nuovo = SessionSet(position: posizione, kind: pianificato.kind,
                                       targetWeight: pianificato.weight, targetReps: pianificato.reps)
                context.insert(nuovo)
                nuovo.sessionExercise = registrato
                sets.append(nuovo)
            }
            esercizi.append(registrato)
            set.append(sets)
            prima.append(precedenti)
            primaATempo.append([])
            piani.append(PlannedExercise(name: esercizio.name, sets: piano))
        }
        macchina.appendExercises(piani, at: ora)
        for (posizione, indice) in macchina.order.enumerated() {
            esercizi[indice].position = posizione
        }
        sessione.lastActivityAt = ora
        aggiornaRecuperoAbituale()
        try? context.save()
    }

    // MARK: Menu «…» dell'esercizio

    /// «Aggiungi set»: un set di lavoro in più in fondo all'esercizio di adesso.
    func aggiungiSet(alle ora: Date = .now) {
        guard let indice = macchina.currentExerciseIndex,
              let nuovo = try? macchina.addSet(toExercise: indice) else { return }
        let piano = macchina.exercises[indice].sets[nuovo]
        let registrato = SessionSet(position: nuovo, kind: piano.kind,
                                    targetWeight: piano.weight, targetReps: piano.reps)
        if aTempo(indice) {
            registrato.targetSeconds = set[indice].last.map(obiettivoSecondi) ?? esercizi[indice].targetSeconds
        }
        context.insert(registrato)
        registrato.sessionExercise = esercizi[indice]
        set[indice].append(registrato)
        sessione.lastActivityAt = ora
        try? context.save()
    }

    /// Nota dell'esercizio per questa sessione.
    func salvaNota(_ testo: String, esercizio indice: Int, alle ora: Date = .now) {
        esercizi[indice].note = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        sessione.lastActivityAt = ora
        try? context.save()
    }

    // MARK: Scaletta

    var scaletta: Lineup {
        Lineup(order: macchina.order, position: macchina.position,
               postponed: Set(esercizi.indices.filter { esercizi[$0].isPostponed }))
    }

    /// Set di lavoro fatti e previsti di un esercizio («1 di 3»).
    func setDiLavoro(di indice: Int) -> (fatti: Int, totale: Int) {
        let lavoro = set[indice].filter { $0.kind != .approach }
        return (lavoro.filter(\.isDone).count, lavoro.count)
    }

    /// Nuovo ordine dopo l'esercizio di adesso (da fare riordinati, poi rimandati).
    func riordina(_ coda: [Int], alle ora: Date = .now) {
        do {
            try macchina.reorderUpcoming(coda)
        } catch {
            return
        }
        for (posizione, indice) in macchina.order.enumerated() {
            esercizi[indice].position = posizione
        }
        sessione.lastActivityAt = ora
        try? context.save()
    }

    /// «Fai dopo questo»: il rimandato torna tra i da fare, subito dopo l'esercizio di adesso.
    func faiDopoQuesto(_ indice: Int, alle ora: Date = .now) {
        esercizi[indice].isPostponed = false
        rimandatiAlle[indice] = nil
        riordina(scaletta.bringingForward(indice), alle: ora)
    }

    /// Set di lavoro fatti e previsti in tutta la sessione.
    var setDiLavoroTotali: (fatti: Int, totale: Int) {
        esercizi.indices.reduce((0, 0)) { somma, indice in
            let conto = setDiLavoro(di: indice)
            return (somma.0 + conto.fatti, somma.1 + conto.totale)
        }
    }

    // MARK: Riepilogo

    /// Riepilogo aperto sopra la sessione («Concludi» o fine dell'ultimo set).
    private(set) var riepilogoAperto = false
    /// Fine della sessione mostrata nel riepilogo (ferma finché il riepilogo è aperto).
    private(set) var fineRiepilogo: Date = .now

    /// «Concludi», o fine dell'ultimo set: il riepilogo si apre, la sessione non è ancora chiusa.
    func apriRiepilogo(alle ora: Date = .now) {
        avviso = nil
        fineRiepilogo = ora
        riepilogoAperto = true
    }

    /// «Continua»: si torna alla sessione da dove era.
    func continua() {
        riepilogoAperto = false
    }

    /// «Completa» su un esercizio con set non fatti: diventa quello di adesso, dal primo set non
    /// fatto, con il cambio esercizio da adesso.
    func completa(_ esercizio: SessionExercise, alle ora: Date = .now) {
        guard let indice = esercizi.firstIndex(where: { $0 === esercizio }) else { return }
        do {
            try macchina.complete(exercise: indice, at: ora)
        } catch {
            return
        }
        esercizi[indice].isPostponed = false
        rimandatiAlle[indice] = nil
        for (posizione, voce) in macchina.order.enumerated() {
            esercizi[voce].position = posizione
        }
        riepilogoAperto = false
        sessione.lastActivityAt = ora
        aggiornaRecuperoAbituale()
        try? context.save()
    }

    /// «Salva sessione»: la sessione si chiude alla fine del riepilogo e va nello storico.
    func salva(alle ora: Date = .now) {
        macchina.finish()
        avviso = nil
        riepilogoAperto = false
        conclusa = true
        sessione.endedAt = sessione.endedAt ?? fineRiepilogo
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

    /// Esercizio e numero di pause per cui il recupero abituale è già calcolato.
    @ObservationIgnored private var recuperoCalcolatoPer: (esercizio: UUID, pause: Int)? = nil

    /// Media dei recuperi dei set di lavoro di questo esercizio (sessioni passate e di oggi).
    /// Si ricalcola solo se cambia l'esercizio o se c'è una pausa nuova (non a ogni tocco).
    private func aggiornaRecuperoAbituale() {
        guard let esercizio = esercizioCorrente?.exercise else {
            recuperoAbituale = nil
            recuperoCalcolatoPer = nil
            return
        }
        let chiave = (esercizio: esercizio.id, pause: macchina.pauses.count)
        if let fatto = recuperoCalcolatoPer, fatto.esercizio == chiave.esercizio, fatto.pause == chiave.pause {
            return
        }
        recuperoCalcolatoPer = chiave
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
