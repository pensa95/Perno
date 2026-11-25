import ActivityKit
import SwiftUI
import UserNotifications
import PernoCore

/// Live Activity della sessione: parte con la sessione, si aggiorna a ogni tocco e si chiude con
/// «Salva sessione», con l'eliminazione o con la chiusura automatica (quando non c'è più una
/// sessione viva). Esegue anche i pulsanti della card, che girano nel processo dell'app.
/// A zero del recupero alla rovescia arriva la notifica «Recupero finito».
@MainActor
final class AttivitaLive {
    static let shared = AttivitaLive()

    private var attivita: Activity<AttivitaSessioneAttributes>?
    private var ultimo: LiveActivityState?
    private weak var sessione: SessioneInCorso?
    private var notificaChiesta = false
    private static let idNotifica = "perno.recupero.finito"

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
        chiediPermessoNotifiche()
        let ingresso = sessione.ingressoLive
        let stato = LiveActivityText.state(for: ingresso, now: ora)
        programmaNotifica(ingresso: ingresso, ora: ora)
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
        attivita = nil
        ultimo = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.idNotifica])
        chiudiAltre(tranne: nil)
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
        case .open:
            break
        }
        mostra(sessione)
    }

    /// «Inizia set» dal blocco schermo: con l'app sospesa la schermata della sessione non gira,
    /// quindi il 3-2-1 lo porta a termine l'azione stessa. I bip vanno in coda tutti insieme
    /// (audio in background): mentre suonano l'app resta sveglia e allo zero fa partire il set.
    private func contoAllaRovescia(_ sessione: SessioneInCorso) async {
        guard case let .countdown(dal, _, _) = sessione.fase else { return }
        let totale = sessione.secondiContoAllaRovescia
        let fine = dal.addingTimeInterval(TimeInterval(totale))
        Segnali.shared.sequenza(bip: Segnali.ultimiTre(prima: fine, durata: totale), via: fine)
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
            withWeight: esercizio?.withWeight ?? true
        )
    }
}

/// Vista invisibile nella radice dell'app: a ogni cambio della sessione aggiorna la Live Activity,
/// e allo zero del recupero alla rovescia la fa passare a «tempo in più».
struct OsservatoreAttivitaLive: View {
    let sessione: SessioneInCorso?
    @State private var scatto = 0

    var body: some View {
        let stato = sessione.map { LiveActivityText.state(for: $0.ingressoLive, now: .now) }
        let prossimo = sessione.flatMap { LiveActivityText.nextChange(for: $0.ingressoLive, now: .now) }
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: stato, initial: true) { _, _ in
                AttivitaLive.shared.mostra(sessione)
            }
            .onChange(of: sessione?.id) { _, _ in
                AttivitaLive.shared.mostra(sessione)
            }
            .task(id: prossimo) {
                guard let prossimo else { return }
                let attesa = prossimo.timeIntervalSinceNow
                if attesa > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000) + 200_000_000)
                }
                guard !Task.isCancelled else { return }
                scatto += 1
            }
            .id(scatto)
    }
}
