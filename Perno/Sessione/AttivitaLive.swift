import ActivityKit
import Observation
import SwiftUI
import UserNotifications
import PernoCore

/// Live Activity della sessione: parte con la sessione, si aggiorna a ogni tocco e si chiude con
/// «Salva sessione», con l'eliminazione o con la chiusura automatica (quando non c'è più una
/// sessione viva). Esegue anche i pulsanti della card, che girano nel processo dell'app.
/// A zero del recupero alla rovescia arriva la notifica «Recupero finito».
///
/// La card segue la sessione da sola (T3): osserva i dati che mostra (`ingressoLive`) con Observation e
/// ha un suo timer per lo zero del recupero, senza passare dalle viste. Con l'app in background SwiftUI non
/// ridisegna le viste, quindi un aggiornamento affidato a `onChange` arrivava solo alla riapertura (la card
/// restava al recupero dopo «Inizia set» col telefono bloccato).
@MainActor
final class AttivitaLive {
    static let shared = AttivitaLive()

    private var attivita: Activity<AttivitaSessioneAttributes>?
    private var ultimo: LiveActivityState?
    private weak var sessione: SessioneInCorso?
    private var notificaChiesta = false
    private static let idNotifica = "perno.recupero.finito"
    /// Ogni osservazione nuova incrementa il turno: le vecchie, quando scattano, non fanno niente.
    private var turnoOsservazione = 0
    /// Prossimo cambio da solo della card (zero del recupero alla rovescia) e il compito che lo aspetta.
    private var prossimoCambio: Date?
    private var compitoCambio: Task<Void, Never>?

    private init() {
        AzioniSessione.gestore = { [weak self] azione in
            await self?.esegui(azione)
        }
    }

    /// Da chiamare a ogni cambio della sessione viva (o quando non c'è più).
    func mostra(_ sessione: SessioneInCorso?, ora: Date = .now) {
        self.sessione = sessione
        guard let sessione else {
            termina()
            return
        }
        // Audio acceso per tutta la sessione (T1): l'app non viene sospesa e i bip partono anche dalla card.
        Segnali.shared.tieniAcceso(true)
        chiediPermessoNotifiche()
        let ingresso = osserva(sessione)
        let stato = LiveActivityText.state(for: ingresso, now: ora)
        programmaNotifica(ingresso: ingresso, ora: ora)
        programmaCambio(LiveActivityText.nextChange(for: ingresso, now: ora))
        guard stato != ultimo || attivita == nil else { return }
        ultimo = stato
        let contenuto = ActivityContent(state: stato, staleDate: nil)
        if let attivita, attivita.attributes.sessione == sessione.id.uuidString {
            Task { await attivita.update(contenuto) }
            return
        }
        // Dopo un riavvio dell'app la card della stessa sessione può essere ancora lì.
        let id = sessione.id.uuidString
        if let esistente = Activity<AttivitaSessioneAttributes>.activities.first(where: { $0.attributes.sessione == id }) {
            attivita = esistente
            Task { await esistente.update(contenuto) }
            chiudiAltre(tranne: id)
            return
        }
        chiudiAltre(tranne: id)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        attivita = try? Activity.request(attributes: AttivitaSessioneAttributes(sessione: id),
                                         content: contenuto, pushType: nil)
    }

    /// Nessuna sessione viva: card e notifica spariscono.
    func termina() {
        Segnali.shared.tieniAcceso(false)
        turnoOsservazione += 1
        programmaCambio(nil)
        attivita = nil
        ultimo = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.idNotifica])
        chiudiAltre(tranne: nil)
    }

    /// Legge i dati della card registrando l'osservazione: al primo cambio (anche con l'app in background)
    /// la card si aggiorna e l'osservazione riparte.
    private func osserva(_ sessione: SessioneInCorso) -> LiveActivityInput {
        turnoOsservazione += 1
        let turno = turnoOsservazione
        return withObservationTracking {
            sessione.ingressoLive
        } onChange: { [weak self, weak sessione] in
            // Scatta prima del cambio: la card si rilegge subito dopo, sul main actor.
            Task { @MainActor [weak self, weak sessione] in
                guard let self, let sessione, turno == self.turnoOsservazione,
                      self.sessione === sessione else { return }
                self.mostra(sessione)
            }
        }
    }

    /// Allo zero del recupero alla rovescia la card passa da sola a «tempo in più».
    private func programmaCambio(_ momento: Date?) {
        guard momento != prossimoCambio else { return }
        prossimoCambio = momento
        compitoCambio?.cancel()
        compitoCambio = nil
        guard let momento else { return }
        compitoCambio = Task { @MainActor [weak self] in
            let attesa = momento.timeIntervalSinceNow
            if attesa > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000) + 200_000_000)
            }
            guard !Task.isCancelled, let self, self.prossimoCambio == momento else { return }
            self.prossimoCambio = nil
            if let sessione = self.sessione { self.mostra(sessione) }
        }
    }

    private func chiudiAltre(tranne id: String?) {
        for vecchia in Activity<AttivitaSessioneAttributes>.activities where vecchia.attributes.sessione != id {
            Task { await vecchia.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: Pulsanti della card

    private func esegui(_ azione: LiveActivityAction) async {
        guard let sessione else { return }
        switch azione {
        case .endWarmUp, .skipWarmUp:
            sessione.riscaldamentoFatto()
        case .start:
            sessione.inizia()
            mostra(sessione)
            await contoAllaRovescia(sessione)
        case .setDone:
            sessione.setFatto()
        case .postpone:
            sessione.rimanda()
        case .addFifteen:
            sessione.aggiungiQuindiciSecondi()
        case .goToNext:
            sessione.vaiAlProssimo()
        case .open:
            break
        }
        mostra(sessione)
    }

    /// «Inizia set» dal blocco schermo: la schermata della sessione può non esserci (sessione ridotta),
    /// quindi il 3-2-1 lo porta a termine l'azione stessa. I bip vanno in coda tutti insieme; con l'audio
    /// tenuto acceso per tutta la sessione l'app è sveglia e suonano subito. Se anche la schermata li chiede,
    /// la stessa sequenza non si programma due volte e il set parte una volta sola.
    private func contoAllaRovescia(_ sessione: SessioneInCorso) async {
        guard case let .countdown(dal, _, _) = sessione.fase else { return }
        let fine = Countdown.end(since: dal)
        Segnali.shared.sequenza(bip: Countdown.beeps(since: dal), via: fine)
        await aspetta(fino: fine)
        guard case let .countdown(ancora, _, _) = sessione.fase, ancora == dal else {
            Segnali.shared.ferma(via: fine)
            return
        }
        sessione.contoAllaRovesciaFinito(alle: fine)
    }

    private func aspetta(fino momento: Date) async {
        let attesa = momento.timeIntervalSinceNow
        guard attesa > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
    }

    // MARK: Notifica a fine recupero

    private func chiediPermessoNotifiche() {
        guard !notificaChiesta else { return }
        notificaChiesta = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Recupero alla rovescia in corso: notifica allo zero (si vede solo con l'app chiusa o lo
    /// schermo bloccato). In ogni altro caso nessuna notifica in attesa.
    private func programmaNotifica(ingresso: LiveActivityInput, ora: Date) {
        let centro = UNUserNotificationCenter.current()
        guard let zero = LiveActivityText.nextChange(for: ingresso, now: ora) else {
            centro.removePendingNotificationRequests(withIdentifiers: [Self.idNotifica])
            return
        }
        let contenuto = UNMutableNotificationContent()
        contenuto.title = LiveActivityText.restOverTitle
        let nomeSet = SessionText.shortName(ingresso.setKind ?? .work, ingresso.setNumber)
        let valore = LiveActivityText.value(for: ingresso)
        contenuto.body = LiveActivityText.restOverBody(setName: nomeSet, exercise: ingresso.exercise ?? ingresso.routine,
                                                       value: valore)
        contenuto.sound = .default
        let attesa = max(1, zero.timeIntervalSince(ora))
        let richiesta = UNNotificationRequest(identifier: Self.idNotifica, content: contenuto,
                                              trigger: UNTimeIntervalNotificationTrigger(timeInterval: attesa,
                                                                                         repeats: false))
        centro.add(richiesta)
    }
}

extension SessioneInCorso {
    /// Quello che la Live Activity mostra di questa sessione.
    var ingressoLive: LiveActivityInput {
        let indice = macchina.currentExerciseIndex ?? macchina.order.first
        let esercizio = indice.map { esercizi[$0] }
        let lavoro = indice.map { voce in set[voce].filter { $0.kind != .approach }.count } ?? 0
        let corrente = setCorrente ?? indice.flatMap { voce in set[voce].first }
        let totali = setDiLavoroTotali
        return LiveActivityInput(
            phase: fase,
            routine: sessione.titolo,
            exercise: esercizio?.name,
            exerciseWorkSets: lavoro,
            setKind: corrente?.kind,
            setNumber: numeroSetCorrente,
            weight: corrente?.targetWeight,
            reps: corrente?.targetReps,
            restMode: modoRecupero,
            restDuration: durataRecupero,
            restLabel: etichettaRecupero,
            countdownSeconds: secondiContoAllaRovescia,
            canPostpone: puoRimandare,
            awaitingChoice: daScegliere,
            sessionStart: sessione.startedAt,
            workSetsDone: totali.fatti,
            workSetsTotal: totali.totale,
            targetSeconds: indice.flatMap { aTempo($0) ? corrente.map(obiettivoSecondi) : nil },
            withWeight: esercizio?.withWeight ?? true,
            awaitingNext: esercizioFinito != nil,
            nextDetail: indice.map(dettaglioProssimo)
        )
    }

    /// «3 set da 8 a 12» (a tempo «3 set da 0:45») dell'esercizio `indice`.
    func dettaglioProssimo(_ indice: Int) -> String {
        let esercizio = esercizi[indice]
        let lavoro = set[indice].filter { $0.kind != .approach }
        return NextExerciseText.detail(sets: lavoro.count, repsMin: esercizio.repsMin, repsMax: esercizio.repsMax,
                                       seconds: esercizio.isTimed
                                           ? (lavoro.first.map(obiettivoSecondi) ?? esercizio.targetSeconds) : nil)
    }
}

/// Vista invisibile nella radice dell'app: dice ad `AttivitaLive` quale sessione è viva (o che non ce n'è
/// più). Gli aggiornamenti della card durante la sessione li fa `AttivitaLive` da sola (osservazione e timer),
/// anche con l'app in background; qui si ripassa anche al ritorno in primo piano.
struct OsservatoreAttivitaLive: View {
    let sessione: SessioneInCorso?
    @Environment(\.scenePhase) private var fase

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: sessione?.id, initial: true) { _, _ in
                AttivitaLive.shared.mostra(sessione)
            }
            .onChange(of: fase) { _, _ in
                AttivitaLive.shared.mostra(sessione)
            }
    }
}
