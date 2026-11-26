import SwiftUI
import UIKit
import PernoCore

/// Schermata della sessione (tavole 1–5): Riscaldamento, Cambio esercizio, 3-2-1, Set in corso, Recupero.
/// Testata, esercizio con regolazioni e promemoria, piastre dei set e dock fisso in basso.
/// Senza audio, vibrazione, notifiche e timer in background (dopo le prove tecniche sul telefono).
struct SessioneView: View {
    let sessione: SessioneInCorso
    /// Freccia giù: la schermata si chiude, la sessione continua (barra ridotta e card in Home).
    let riduci: () -> Void
    /// Sessione chiusa («Salva sessione» nel riepilogo).
    let chiudi: () -> Void
    /// «Elimina sessione» nel riepilogo.
    let elimina: () -> Void

    @State private var correzione: Correzione?
    /// Progressi: dettaglio dell'esercizio di adesso, in un foglio.
    @State private var progressi: Exercise?
    @Environment(\.colorScheme) private var schema
    @Environment(\.accessibilityReduceMotion) private var menoMovimento
    @AppStorage(Impostazioni.chiediFaccina) private var chiediFaccina = true
    /// Regolazioni (15 pt, 18 pt in evidenza) e icone accanto: crescono con «Testo più grande».
    @ScaledMetric(relativeTo: .subheadline) private var dimensioneRegolazioni: CGFloat = 15
    @ScaledMetric(relativeTo: .title3) private var dimensioneRegolazioniEvidenza: CGFloat = 18
    @AppStorage(Impostazioni.partiDaSolo) private var partiDaSolo = false
    @State private var scalettaAperta = false
    @State private var aggiungiAperto = false
    @State private var sostituisciAperto = false
    @State private var scriviNota = false
    @State private var testoNota = ""

    /// Set fatto aperto in Correggi set.
    struct Correzione: Identifiable {
        let esercizio: Int
        let set: Int
        var id: String { "\(esercizio)-\(set)" }
    }

    var body: some View {
        ZStack {
            if sessione.riepilogoAperto {
                RiepilogoView(sessione: sessione.sessione,
                              fine: sessione.fineRiepilogo,
                              continua: { sessione.continua() },
                              completa: { esercizio in sessione.completa(esercizio) },
                              salva: { sessione.salva() },
                              elimina: elimina)
                    .transition(menoMovimento ? .opacity : .move(edge: .trailing))
            } else {
                schermata
                    .transition(menoMovimento ? .opacity : .move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessione.riepilogoAperto)
        .onChange(of: sessione.fase) { _, fase in annunciaFase(fase) }
        .onChange(of: sessione.conclusa) { _, conclusa in
            if conclusa { chiudi() }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var schermata: some View {
        // Solo i tempi (testata, dock, 3-2-1) si aggiornano ogni mezzo secondo: il resto della
        // schermata si ridisegna solo quando cambia la sessione.
        ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            TimelineView(.periodic(from: .now, by: 0.5)) { contesto in
                                testata(ora: contesto.date)
                            }
                            if case .warmUp = sessione.fase {
                                riscaldamento
                            } else if sessione.daScegliere {
                                SceltaEsercizio(sessione: sessione) { aggiungiAperto = true }
                            } else {
                                esercizio
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    TimelineView(.periodic(from: .now, by: 0.5)) { contesto in
                        dock(ora: contesto.date)
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                if sessione.avviso != nil, let set = sessione.setDellAvviso {
                    avvisoSetFatto(set)
                }

                if case let .countdown(dal, _, _) = sessione.fase {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { contesto in
                        contoAllaRovescia(ora: contesto.date, dal: dal)
                    }
                }
        }
        .background(Color.lamiera.ignoresSafeArea())
        .task(id: inizioContoAllaRovescia) {
            guard let dal = inizioContoAllaRovescia else { return }
            let fine = Countdown.end(since: dal)
            let attesa = fine.timeIntervalSinceNow
            if attesa > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            Segnali.shared.vibraVia()
            sessione.contoAllaRovesciaFinito(alle: fine)
        }
        .task(id: inizioContoAllaRovescia) {
            // Bip del 3-2-1 e «via»: programmati subito sugli stessi istanti dei numeri e dell'anello
            // (`Countdown`), così cadono al cambio del numero e suonano anche se lo schermo si blocca.
            // Le vibrazioni seguono a ogni secondo (solo in primo piano).
            guard let dal = inizioContoAllaRovescia else { return }
            await segnaliFinoA(Countdown.end(since: dal), istanti: Countdown.beeps(since: dal))
        }
        .task(id: fineRecuperoConBip) {
            // Ultimi 3 secondi del recupero alla rovescia: bip e vibrazione come nel 3-2-1. Con l'audio
            // tenuto acceso per tutta la sessione (T1) i bip suonano anche a schermo bloccato, oltre
            // alla notifica «Recupero finito»; la vibrazione si sente solo con l'app in primo piano.
            guard let fine = fineRecuperoConBip else { return }
            let anticipo = fine.timeIntervalSinceNow - 3.5
            if anticipo > 0 {
                try? await Task.sleep(nanoseconds: UInt64(anticipo * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await segnaliFinoA(fine, durata: 3, vibraAllaFine: true)
            if !Task.isCancelled, fine.timeIntervalSinceNow <= 0 {
                Annuncio.voiceOver("Recupero finito")
            }
        }
        .task(id: fineRecuperoAutomatica) {
            // «Parti da solo a fine recupero»: a zero del conto alla rovescia parte il 3-2-1.
            guard let fine = fineRecuperoAutomatica else { return }
            let attesa = fine.timeIntervalSinceNow
            if attesa > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
            }
            guard !Task.isCancelled, fineRecuperoAutomatica == fine else { return }
            sessione.inizia()
        }
        .task(id: sessione.fineSetATempo) {
            // Set a tempo (UI v5): bip e vibrazione negli ultimi 3 secondi come nel 3-2-1, poi a zero
            // il set si chiude da solo con la durata piena. Messi in coda subito, i bip suonano anche
            // a schermo bloccato; se l'app torna in primo piano dopo lo zero, il set si chiude allo zero.
            guard let fine = sessione.fineSetATempo else { return }
            let anticipo = fine.timeIntervalSinceNow - 3.5
            if anticipo > 0 {
                try? await Task.sleep(nanoseconds: UInt64(anticipo * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await segnaliFinoA(fine, durata: 3, vibraAllaFine: true)
            let attesa = fine.timeIntervalSinceNow
            if attesa > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
            }
            guard !Task.isCancelled, sessione.fineSetATempo == fine else { return }
            sessione.setFatto(alle: fine)
        }
        .task(id: sessione.avviso?.scadenza) {
            guard let scadenza = sessione.avviso?.scadenza else { return }
            let attesa = scadenza.timeIntervalSinceNow
            if attesa > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
            }
            guard !Task.isCancelled, sessione.avviso?.scadenza == scadenza else { return }
            sessione.chiudiAvviso()
        }
        .sheet(isPresented: $aggiungiAperto) {
            AggiungiEserciziView(sessione: sessione)
        }
        .sheet(isPresented: $sostituisciAperto) {
            if let indice = sessione.indiceEsercizio {
                SostituisciEsercizioView(sessione: sessione, esercizio: indice)
            }
        }
        .sheet(isPresented: $scalettaAperta) {
            ScalettaView(sessione: sessione)
        }
        .sheet(item: $correzione) { correzione in
            CorreggiSetView(sessione: sessione, esercizio: correzione.esercizio, indice: correzione.set)
        }
        .sheet(item: $progressi) { esercizio in
            NavigationStack {
                DettaglioEsercizioView(esercizio: esercizio, indietro: "Sessione")
                    .destinazioniStorico()
            }
        }
    }

    /// Fine del recupero alla rovescia, se deve partire da solo (impostazione attiva e set da fare).
    private var fineRecuperoAutomatica: Date? {
        guard partiDaSolo, sessione.modoRecupero == .countdown, case let .rest(dal) = sessione.fase,
              sessione.setCorrente != nil else { return nil }
        return dal.addingTimeInterval(sessione.durataRecupero)
    }

    /// Fine del recupero alla rovescia che non parte da solo (se parte da solo, suona il 3-2-1).
    private var fineRecuperoConBip: Date? {
        guard sessione.modoRecupero == .countdown, case let .rest(dal) = sessione.fase,
              sessione.setCorrente != nil, fineRecuperoAutomatica == nil else { return nil }
        return dal.addingTimeInterval(sessione.durataRecupero)
    }

    /// Mette in coda i bip fino a `fine` e vibra a ogni secondo (`vibraAllaFine`: anche la vibrazione
    /// forte allo zero). Se il compito viene annullato prima dello zero (3-2-1 annullato, +15 s,
    /// set iniziato prima) ferma i bip rimasti; dopo lo zero il «via» finisce di suonare.
    private func segnaliFinoA(_ fine: Date, durata: Int = 3, istanti: [Date]? = nil,
                              vibraAllaFine: Bool = false) async {
        guard fine.timeIntervalSinceNow > 0 else { return }
        let istanti = istanti ?? Segnali.ultimiTre(prima: fine, durata: durata)
        Segnali.shared.sequenza(bip: istanti, via: fine)
        for istante in istanti + [fine] {
            let attesa = istante.timeIntervalSinceNow
            if attesa < -0.5 { continue }
            if attesa > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
            }
            guard !Task.isCancelled else {
                if fine.timeIntervalSinceNow > 0.05 { Segnali.shared.ferma(via: fine) }
                return
            }
            if istante != fine {
                Segnali.shared.vibraSecondo()
            } else if vibraAllaFine {
                Segnali.shared.vibraVia()
            }
        }
    }

    /// VoiceOver: annuncia la fase nuova (chi non guarda lo schermo sentiva solo i bip).
    private func annunciaFase(_ fase: SessionPhase) {
        let tipo = sessione.setCorrente?.kind ?? .work
        let numero = sessione.numeroSetCorrente
        let testo: String
        switch fase {
        case .warmUp:
            testo = "Riscaldamento in corso"
        case .changeover:
            if let indice = sessione.macchina.currentExerciseIndex, indice < sessione.esercizi.count {
                testo = "Cambio esercizio. Prossimo: \(sessione.esercizi[indice].name)"
            } else {
                testo = "Cambio esercizio"
            }
        case .countdown:
            testo = "\(SessionText.countdownTitle(tipo, numero)) \(sessione.secondiContoAllaRovescia) secondi"
        case .inSet:
            testo = SessionText.inProgress(tipo, numero)
        case .rest:
            testo = "Recupero"
        case .finished:
            testo = "Tutti i set fatti"
        }
        Annuncio.voiceOver(testo)
    }

    private var inizioContoAllaRovescia: Date? {
        if case let .countdown(dal, _, _) = sessione.fase { return dal }
        return nil
    }

    // MARK: Testata

    private func testata(ora: Date) -> some View {
        HStack(spacing: 4) {
            PulsanteTondo(icona: "chevron.down", etichetta: "Riduci la sessione", azione: riduci)
            VStack(spacing: 0) {
                Text(sessione.sessione.titolo)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
                    .lineLimit(1)
                Text(SessionText.clock(ora.timeIntervalSince(sessione.sessione.startedAt)))
                    .font(.piastra(22))
                    .monospacedDigit()
                    .foregroundStyle(Color.inchiostro)
            }
            .frame(maxWidth: .infinity)
            PulsanteTondo(icona: "list.bullet", etichetta: "Scaletta") {
                scalettaAperta = true
            }
            Button("Concludi") { sessione.apriRiepilogo() }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(width: 76, height: 44, alignment: .trailing)
                .buttonStyle(.plain)
        }
    }

    // MARK: Riscaldamento

    /// Tavola 1 (UI v6): stesso layout delle altre fasi, senza icona (il colore lo dà il dock);
    /// sottotitolo «A seguire:» sopra l'elenco degli esercizi.
    private var riscaldamento: some View {
        VStack(alignment: .leading, spacing: 0) {
            titoloEsercizio("Riscaldamento",
                            sottotitolo: sessione.ordineDiOggi.isEmpty ? nil : "A seguire:")
                .padding(.top, 24)

            if !sessione.ordineDiOggi.isEmpty {
                Pila {
                    ForEach(Array(sessione.ordineDiOggi.enumerated()), id: \.offset) { indice, esercizio in
                        HStack(spacing: 12) {
                            Text("\(indice + 1)")
                                .font(.piastra(22))
                                .foregroundStyle(Color.inchiostroTenue)
                                .frame(width: 22, alignment: .leading)
                            Text(esercizio.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inchiostro)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(setDiLavoro(esercizio))
                                .font(.footnote)
                                .foregroundStyle(Color.inchiostroTenue)
                        }
                        .vocePila(altezza: 52)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    /// Testata dell'esercizio (UI v6, tavole 1–7): nome sopra (40 pt), sottotitolo sotto (15 pt, tenue).
    private func titoloEsercizio(_ nome: String, sottotitolo: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nome)
                .font(.piastra(40))
                .foregroundStyle(Color.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            if let sottotitolo {
                Text(sottotitolo)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func setDiLavoro(_ esercizio: SessionExercise) -> String {
        let quanti = esercizio.sets.filter { $0.kind != .approach }.count
        return quanti == 1 ? "1 set" : "\(quanti) set"
    }

    // MARK: Esercizio

    @ViewBuilder
    private var esercizio: some View {
        if let esercizio = sessione.esercizioCorrente, let indice = sessione.indiceEsercizio {
            HStack(alignment: .top, spacing: 8) {
                titoloEsercizio(esercizio.name, sottotitolo: esercizio.isTimed
                    ? TimedText.exerciseHeader(position: sessione.numeroEsercizio,
                                               count: sessione.esercizi.count,
                                               sets: sessione.setDiLavoro(di: indice).totale,
                                               seconds: sessione.set[indice].first
                                                   .map(sessione.obiettivoSecondi) ?? esercizio.targetSeconds)
                    : SessionText.exerciseHeader(position: sessione.numeroEsercizio,
                                                 count: sessione.esercizi.count,
                                                 repsMin: esercizio.repsMin, repsMax: esercizio.repsMax))
                Spacer(minLength: 0)
                menuEsercizio(esercizio)
            }
            .padding(.top, 24)

            regolazioni(esercizio)

            // Piastre dei set con i recuperi in mezzo (UI v6): i recuperi finiti come riga sottile con il tempo
            // misurato, quello in corso come piastrina blu prima del set dopo (che dice «prossimo»).
            let riposi = PlateText.measuredRests(exercise: indice, setCount: sessione.set[indice].count,
                                                 completed: sessione.macchina.completedSets,
                                                 pauses: sessione.macchina.pauses)
            VStack(spacing: 4) {
                ForEach(Array(sessione.set[indice].enumerated()), id: \.offset) { posizione, set in
                    Group {
                        if posizione == sessione.macchina.setIndex,
                           indice == sessione.macchina.currentExerciseIndex {
                            recuperoPrima(esercizio: esercizio)
                        }
                        Button {
                            correzione = Correzione(esercizio: indice, set: posizione)
                        } label: {
                            piastra(set, posizione: posizione, esercizio: indice)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Correggi set")
                        .modifier(ScorriPerTogliere(attivo: sessione.puoTogliere(esercizio: indice, set: posizione)) {
                            sessione.togliSet(esercizio: indice, set: posizione)
                        })
                        if let riposo = riposi[safe: posizione] ?? nil {
                            RigaRecupero(testo: PlateText.restDone(riposo))
                        }
                    }
                }

                // «Aggiungi set» (UI v6, tavola 9): tratteggiato, non primario; un set uguale all'ultimo.
                Button {
                    withAnimation(.snappy) { sessione.aggiungiSet() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Aggiungi set")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(Color.inchiostro)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        BordoTratteggiato(colore: Color.inchiostro.opacity(0.3), spessore: 1.5,
                                          trattino: 5, spazio: 4, raggio: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.top, 16)
        }
    }

    /// Prima del set di adesso: durante il recupero la piastrina blu con il tempo del dock; durante il 3-2-1
    /// che parte dal recupero la riga del recupero appena finito (il tempo si registra alla fine del 3-2-1).
    @ViewBuilder
    private func recuperoPrima(esercizio: SessionExercise) -> some View {
        switch sessione.fase {
        case let .rest(dal):
            TimelineView(.periodic(from: .now, by: 0.5)) { contesto in
                PiastrinaRecupero(
                    tempo: RestTimer.display(mode: sessione.modoRecupero,
                                             elapsed: contesto.date.timeIntervalSince(dal),
                                             duration: sessione.durataRecupero),
                    nota: PlateText.restNote(fixed: esercizio.fixedRest, usual: sessione.recuperoAbituale))
            }
        case let .countdown(dal, inizioPausa, tipo) where tipo == .rest:
            RigaRecupero(testo: PlateText.restDone(dal.timeIntervalSince(inizioPausa)))
        default:
            EmptyView()
        }
    }

    /// Recupero in corso: il set di adesso è «prossimo» (la piastrina del recupero è «adesso»).
    private var inRecupero: Bool {
        if case .rest = sessione.fase { return true }
        return false
    }

    /// Menu «…» dell'esercizio (tavola 12, UI v6): Aggiungi nota, Sostituisci (solo se l'esercizio ha set da
    /// fare e nessuno è in corso), Progressi, Rimanda. «Aggiungi set» è il pulsante sotto i set (T9).
    private func menuEsercizio(_ esercizio: SessionExercise) -> some View {
        Menu {
            Button {
                testoNota = esercizio.note
                scriviNota = true
            } label: {
                Text(esercizio.note.isEmpty ? "Aggiungi nota" : "Modifica nota")
                Text("La ritrovi la prossima volta")
                Image(systemName: "text.bubble")
            }
            if let indice = sessione.indiceEsercizio, sessione.puoSostituire(indice) {
                Button {
                    sostituisciAperto = true
                } label: {
                    Text("Sostituisci \(esercizio.name)")
                    Text("Tutto l'esercizio, solo per oggi")
                    Image(systemName: "arrow.left.arrow.right")
                }
            }
            Button {
                progressi = esercizio.exercise
            } label: {
                Text("Progressi")
                Image(systemName: "chart.line.uptrend.xyaxis")
            }
            .disabled(esercizio.exercise == nil)
            Button {
                sessione.rimanda()
            } label: {
                Text("Rimanda")
                Image(systemName: "arrow.right")
            }
            .disabled(!sessione.puoRimandare)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(width: 44, height: 44)
                .background(Color.foglio, in: Circle())
        }
        .accessibilityLabel("Altre azioni")
        .alert(esercizio.name, isPresented: $scriviNota) {
            TextField("Nota per oggi", text: $testoNota)
            Button("Annulla", role: .cancel) {}
            Button("Salva") {
                if let indice = sessione.indiceEsercizio {
                    sessione.salvaNota(testoNota, esercizio: indice)
                }
            }
        } message: {
            Text("La ritrovi la prossima volta.")
        }
    }

    /// Card bianca: regolazioni (più grandi durante il cambio esercizio) e promemoria; sotto una riga, la nota
    /// della volta scorsa (UI v6, tavola 2) e quella di oggi («la ritrovi la prossima volta», tavola 13).
    @ViewBuilder
    private func regolazioni(_ esercizio: SessionExercise) -> some View {
        let setup = esercizio.setup.trimmingCharacters(in: .whitespacesAndNewlines)
        let promemoria = Cues.split(esercizio.cues)
        let nota = esercizio.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let precedente = esercizio.notaVoltaScorsa
        if !setup.isEmpty || !promemoria.isEmpty || !nota.isEmpty || precedente != nil {
            let inEvidenza: Bool = {
                if case .changeover = sessione.fase, sessione.esercizioFinito == nil { return true }
                return false
            }()
            VStack(alignment: .leading, spacing: 8) {
                if !setup.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "wrench.adjustable")
                            .font(.system(size: dimensioneRegolazioni, weight: .semibold))
                        Text(setup)
                            .font(.system(size: inEvidenza ? dimensioneRegolazioniEvidenza : dimensioneRegolazioni,
                                          weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.inchiostro)
                }
                ForEach(promemoria, id: \.self) { voce in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "pin")
                            .font(.system(size: dimensioneRegolazioni, weight: .semibold))
                        Text(voce)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.inchiostroTenue)
                }
                let primaRiga = setup.isEmpty && promemoria.isEmpty
                if let precedente {
                    rigaNota(etichetta: ExerciseNoteText.lastTime(precedente.date), testo: precedente.note,
                             separata: !primaRiga)
                }
                if !nota.isEmpty {
                    rigaNota(etichetta: ExerciseNoteText.today, testo: nota,
                             separata: !primaRiga || precedente != nil)
                }
            }
            .padding(inEvidenza ? 16 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 16)
        }
    }

    /// Nota nella card: fumetto, etichetta tenue (13 pt) e testo (15 pt, semibold), separata da una riga sottile.
    private func rigaNota(etichetta: String, testo: String, separata: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: dimensioneRegolazioni, weight: .semibold))
                .foregroundStyle(Color.inchiostro)
            VStack(alignment: .leading, spacing: 2) {
                Text(etichetta)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
                Text(testo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, separata ? 10 : 0)
        .overlay(alignment: .top) {
            if separata {
                Rectangle()
                    .fill(Color.inchiostro.opacity(0.1))
                    .frame(height: 1)
            }
        }
        .padding(.top, separata ? 2 : 0)
        .accessibilityElement(children: .combine)
    }

    private func piastra(_ set: SessionSet, posizione: Int, esercizio indice: Int) -> some View {
        if sessione.aTempo(indice) {
            return piastraATempo(set, posizione: posizione, esercizio: indice)
        }
        let numeri = SessionText.numbers(sessione.set[indice].map(\.kind))
        let numero = numeri[posizione]
        let nome = SessionText.shortName(set.kind, numero)
        let prima = set.kind == .approach ? nil : sessione.prima[indice][safe: numero - 1]
        let notaPrima = prima.map { "prima " + SessionText.weightReps($0.weight, $0.reps) }

        // Avvicinamenti in tinta calda e senza percentuale (tavola 2, UI v6).
        let calda = set.kind == .approach
        if set.isDone, let peso = set.weight, let ripetizioni = set.reps {
            // Fatta (UI v6): badge «+3» oltre l'obiettivo e faccina a destra (solo set di lavoro).
            return PiastraSet(nome: nome, valore: SessionText.weightReps(peso, ripetizioni),
                              stato: .fatta(nota: nil), calda: calda,
                              badge: calda ? nil : PlateText.overTarget(done: ripetizioni, target: set.targetReps),
                              faccina: calda ? nil : set.feeling)
        }

        let obiettivo = SessionText.weightReps(set.targetWeight, set.targetReps)
        let diAdesso = posizione == sessione.macchina.setIndex && indice == sessione.macchina.currentExerciseIndex
        guard diAdesso, !inRecupero else {
            let prossimo = diAdesso
            return PiastraSet(nome: nome, valore: obiettivo, stato: .daFare, calda: calda,
                              notaDaFare: prossimo ? PlateText.next : "obiettivo")
        }

        let inCorso: Bool = {
            if case .inSet = sessione.fase { return true }
            return false
        }()
        if calda {
            return PiastraSet(nome: nome, valore: obiettivo, stato: .adesso(
                etichetta: inCorso ? "\(nome), in corso" : "\(nome), avvicinamento",
                evidenza: nil, nota: nil), calda: true)
        }
        let differenza = prima.flatMap { SessionText.delta(today: set.targetWeight, before: $0.weight) }
        return PiastraSet(nome: nome, valore: obiettivo, stato: .adesso(
            etichetta: inCorso ? "\(nome), in corso" : "\(nome), obiettivo",
            evidenza: differenza, nota: notaPrima))
    }

    /// Piastra di un set a tempo (UI v5): «10 × 0:45» con il peso, «0:45» senza.
    private func piastraATempo(_ set: SessionSet, posizione: Int, esercizio indice: Int) -> PiastraSet {
        let numeri = SessionText.numbers(sessione.set[indice].map(\.kind))
        let nome = SessionText.shortName(set.kind, numeri[posizione])
        let obiettivo = sessione.obiettivoSecondi(set)
        if set.isDone {
            let fatti = set.seconds ?? obiettivo
            return PiastraSet(nome: nome,
                              valore: TimedText.value(seconds: fatti, weight: sessione.pesoATempo(indice, set.weight ?? set.targetWeight)),
                              stato: .fatta(nota: TimedText.doneNote(seconds: fatti, target: obiettivo)),
                              faccina: set.feeling)
        }
        let valore = TimedText.value(seconds: obiettivo, weight: sessione.pesoATempo(indice, set.targetWeight))
        let diAdesso = posizione == sessione.macchina.setIndex && indice == sessione.macchina.currentExerciseIndex
        guard diAdesso, !inRecupero else {
            let prossimo = diAdesso
            return PiastraSet(nome: nome, valore: valore, stato: .daFare,
                              notaDaFare: prossimo ? PlateText.next : "obiettivo")
        }
        let inCorso: Bool = {
            if case .inSet = sessione.fase { return true }
            return false
        }()
        // «+5 s» e «prima 10 × 0:40» rispetto allo stesso set della volta prima.
        let prima = set.kind == .approach ? nil : sessione.primaATempo[indice][safe: numeri[posizione] - 1]
        return PiastraSet(nome: nome, valore: valore, stato: .adesso(
            etichetta: inCorso ? "\(nome), in corso" : "\(nome), obiettivo",
            evidenza: prima.flatMap { TimedText.delta(today: obiettivo, before: $0.seconds) },
            nota: prima.map { TimedText.before(seconds: $0.seconds, weight: sessione.pesoATempo(indice, $0.weight)) }))
    }

    // MARK: Dock

    @ViewBuilder
    private func dock(ora: Date) -> some View {
        switch sessione.fase {
        case let .warmUp(dal):
            DockSessione(
                sfondo: .riscaldamento, coloreEtichetta: .riscaldamentoTenue, coloreTesto: .white,
                etichetta: "Riscaldamento in corso",
                tempo: SessionText.clock(ora.timeIntervalSince(dal)),
                secondario: DockSessione.Secondario(titolo: "Salta") { sessione.riscaldamentoFatto() },
                principale: DockSessione.Pulsante(titolo: "Riscaldamento fatto") { sessione.riscaldamentoFatto() })
        case let .changeover(dal) where sessione.esercizioFinito != nil:
            // Fine dell'ultimo set di un esercizio (tavola 6): si resta qui, «Vai a …» apre il cambio.
            let prossimo = sessione.macchina.currentExerciseIndex.map { sessione.esercizi[$0] }
            let nome = prossimo?.name ?? ""
            DockSessione(
                sfondo: .piastra, coloreEtichetta: .piastraTenue, coloreTesto: .white,
                etichetta: "Cambio esercizio",
                tempo: SessionText.clock(ora.timeIntervalSince(dal)),
                principale: DockSessione.Pulsante(titolo: NextExerciseText.goTo(nome)) {
                    sessione.vaiAlProssimo()
                },
                sottotitolo: sessione.macchina.currentExerciseIndex.map {
                    NextExerciseText.subtitle(exercise: nome, detail: sessione.dettaglioProssimo($0))
                })
        case let .changeover(dal):
            DockSessione(
                sfondo: .piastra, coloreEtichetta: .piastraTenue, coloreTesto: .white,
                etichetta: "Cambio esercizio",
                tempo: SessionText.clock(ora.timeIntervalSince(dal)),
                secondario: sessione.puoRimandare
                    ? DockSessione.Secondario(titolo: "Rimanda", azione: { sessione.rimanda() })
                    : nil,
                principale: sessione.daScegliere
                    ? Optional(DockSessione.Pulsante(titolo: "Scegli esercizi", icona: "plus",
                                                     azione: { aggiungiAperto = true }))
                    : pulsanteInizia)
        case let .countdown(dal, inizioPausa, tipo):
            DockSessione(
                sfondo: .piastra, coloreEtichetta: .piastraTenue, coloreTesto: .white,
                etichetta: tipo == .rest ? "Recupero finito" : "Cambio esercizio",
                tempo: SessionText.clock(dal.timeIntervalSince(inizioPausa)))
        case let .inSet(dal) where setCorrenteATempo:
            let obiettivo = sessione.setCorrente.map(sessione.obiettivoSecondi) ?? DurationLimits.standard
            let trascorsi = ora.timeIntervalSince(dal)
            DockSessione(
                sfondo: .foglio, coloreEtichetta: .inchiostroTenue, coloreTesto: .inchiostro,
                etichetta: setCorrente(TimedText.inProgress),
                tempo: TimedText.remaining(elapsed: trascorsi, target: obiettivo),
                principale: DockSessione.Pulsante(titolo: setCorrente(SessionText.doneTitle), sfondo: .inchiostro, testo: .suInchiostro) {
                    sessione.setFatto()
                },
                bordoSopra: true,
                notaTempo: TimedText.of(seconds: obiettivo),
                avanzamento: TimedText.progress(elapsed: trascorsi, target: obiettivo))
        case let .inSet(dal):
            DockSessione(
                sfondo: .foglio, coloreEtichetta: .inchiostroTenue, coloreTesto: .inchiostro,
                etichetta: setCorrente(SessionText.inProgress),
                tempo: SessionText.clock(ora.timeIntervalSince(dal)),
                principale: DockSessione.Pulsante(titolo: setCorrente(SessionText.doneTitle), sfondo: .inchiostro, testo: .suInchiostro) {
                    sessione.setFatto()
                },
                bordoSopra: true)
        case let .rest(dal):
            DockSessione(
                sfondo: .recupero, coloreEtichetta: .recuperoTenue, coloreTesto: .white,
                etichetta: sessione.etichettaRecupero,
                tempo: RestTimer.display(mode: sessione.modoRecupero, elapsed: ora.timeIntervalSince(dal),
                                         duration: sessione.durataRecupero),
                secondario: sessione.modoRecupero == .countdown
                    ? DockSessione.Secondario(titolo: "+15 s", azione: { sessione.aggiungiQuindiciSecondi() })
                    : nil,
                principale: pulsanteInizia,
                azioneTempo: { sessione.cambiaModoRecupero() })
        case .finished:
            EmptyView()
        }
    }

    private var pulsanteInizia: DockSessione.Pulsante? {
        guard let set = sessione.setCorrente else { return nil }
        let dettaglio: String
        if let indice = sessione.macchina.currentExerciseIndex, sessione.aTempo(indice) {
            dettaglio = TimedText.value(seconds: sessione.obiettivoSecondi(set),
                                        weight: sessione.pesoATempo(indice, set.targetWeight))
        } else {
            dettaglio = SessionText.weightReps(set.targetWeight, set.targetReps)
        }
        return DockSessione.Pulsante(titolo: setCorrente(SessionText.startTitle), dettaglio: dettaglio) {
            sessione.inizia()
        }
    }

    /// Il set di adesso è di un esercizio a tempo.
    private var setCorrenteATempo: Bool {
        sessione.macchina.currentExerciseIndex.map(sessione.aTempo) ?? false
    }

    private func setCorrente(_ testo: (SetKind, Int) -> String) -> String {
        testo(sessione.setCorrente?.kind ?? .work, sessione.numeroSetCorrente)
    }

    // MARK: Avviso dopo «Set fatto»

    /// Avviso dopo «Set fatto» (UI v6, tavole 5, 6, 7 e 16): tre righe che non escono mai dai bordi e non
    /// scorrono in orizzontale. «Set N fatto, 65 kg» con «Annulla»; ripetizioni (o durata) grandi al centro con
    /// − e + da 64 e lo scarto sull'obiettivo sotto; «Com'è andato?» con le faccine (solo set di lavoro, se
    /// l'impostazione è accesa). In fondo la barretta del tempo rimasto: 10 s, ogni tocco li rinnova.
    private func avvisoSetFatto(_ set: SessionSet) -> some View {
        let indice = sessione.avviso?.esercizio ?? 0
        let numeri = SessionText.numbers(sessione.set[indice].map(\.kind))
        let numero = numeri[safe: sessione.avviso?.set ?? 0] ?? 1
        let aTempo = sessione.aTempo(indice)
        let peso: Double? = aTempo
            ? sessione.pesoATempo(indice, set.weight ?? set.targetWeight)
            : (set.weight ?? set.targetWeight)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                Text(NoticeText.title(set.kind, numero, weight: peso))
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    sessione.annullaSetFatto()
                } label: {
                    Text("Annulla")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color.lamiera, in: Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            .padding(.leading, 4)

            if aTempo {
                let obiettivo = sessione.obiettivoSecondi(set)
                let secondi = set.seconds ?? obiettivo
                rigaValore(valore: Clock.text(Double(secondi)),
                           sotto: TimedText.doneNote(seconds: secondi, target: obiettivo),
                           meno: "Cinque secondi in meno", piu: "Cinque secondi in più",
                           menoAttivo: secondi > DurationLimits.range.lowerBound,
                           piuAttivo: secondi < DurationLimits.range.upperBound) { passo in
                    sessione.cambiaSecondi(di: passo)
                }
                Text(TimedText.noticeDetail(seconds: secondi, target: obiettivo))
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
                    .padding(.top, -4)
            } else {
                let ripetizioni = set.reps ?? set.targetReps
                rigaValore(valore: "\(ripetizioni)",
                           sotto: NoticeText.repsDelta(done: ripetizioni, target: set.targetReps),
                           meno: "Una ripetizione in meno", piu: "Una ripetizione in più",
                           menoAttivo: ripetizioni > EntryLimits.reps.lowerBound,
                           piuAttivo: ripetizioni < EntryLimits.reps.upperBound) { passo in
                    sessione.cambiaRipetizioni(di: passo)
                }
            }

            if chiediFaccina && set.kind != .approach {
                SceltaFaccina(scelta: set.feeling) { faccina in
                    sessione.scegliFaccina(faccina)
                }
            }

            if let scadenza = sessione.avviso?.scadenza {
                TimelineView(.animation(minimumInterval: 0.1)) { contesto in
                    BarraAvviso(restante: NoticeText.remaining(until: scadenza, now: contesto.date))
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { sessione.toccaAvviso() }
        .modifier(StileAvviso(schema: schema, inFondo: sessione.fase == .finished))
    }

    /// Riga centrale dell'avviso: − da 64, valore a 48 con lo scarto sotto, + da 64.
    private func rigaValore(valore: String, sotto: String, meno: String, piu: String,
                            menoAttivo: Bool, piuAttivo: Bool,
                            cambia: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            tastoAvviso("minus", etichetta: meno, attivo: menoAttivo) { cambia(-1) }
            VStack(spacing: 2) {
                Text(valore)
                    .font(.piastra(48))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(sotto)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            tastoAvviso("plus", etichetta: piu, attivo: piuAttivo) { cambia(1) }
        }
    }

    private func tastoAvviso(_ icona: String, etichetta: String, attivo: Bool,
                             azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            Image(systemName: icona)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 64, height: 64)
                .background(Color.lamiera, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!attivo)
        .opacity(attivo ? 1 : 0.35)
        .accessibilityLabel(etichetta)
    }

    // MARK: 3-2-1

    /// Anello sottile che si svuota nel tempo del 3-2-1, numero bianco al centro
    /// (al posto del cerchio giallo pieno: scelta dell'utente del 24/11, alternativa A).
    /// Numero e anello si leggono da `Countdown` con la stessa data di partenza dei bip.
    private func contoAllaRovescia(ora: Date, dal: Date) -> some View {
        let restante = Countdown.remaining(at: ora, since: dal)
        return VStack(spacing: 16) {
            Text(setCorrente(SessionText.countdownTitle))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.piastraTenue)
            Text("\(Countdown.value(at: ora, since: dal))")
                .font(.piastra(140))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 200, height: 200)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: restante)
                        .stroke(Color.perno, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            Button {
                sessione.annullaContoAllaRovescia()
            } label: {
                Text("Annulla")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor(hex: 0x14181B)).opacity(0.72).ignoresSafeArea())
    }
}

/// Forma dell'avviso dopo «Set fatto» (sopra il dock), uguale per ripetizioni e tempo: 12 pt dai bordi,
/// angoli da 24, ombra; testo fino a xxxLarge così le righe non escono mai dai bordi.
private struct StileAvviso: ViewModifier {
    let schema: ColorScheme
    /// Fine sessione (tavola 7): senza dock l'avviso scende in fondo.
    var inFondo = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.inchiostro)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.top, 12)
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(Color.foglio, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                // Nel tema scuro l'avviso ha un bordo sottile per staccarsi dal dock.
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.inchiostro.opacity(schema == .dark ? 0.08 : 0), lineWidth: 1)
            }
            .shadow(color: Color.ombra.opacity(schema == .dark ? 0.5 : 0.24), radius: 16, x: 0, y: 12)
            .shadow(color: Color.ombra.opacity(0.16), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 12)
            .padding(.bottom, inFondo ? 40 : 236)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
            .transition(.opacity)
    }
}

/// Barretta del tempo che resta prima che l'avviso si chiuda da solo (alta 4, dentro la card).
private struct BarraAvviso: View {
    let restante: Double

    var body: some View {
        GeometryReader { spazio in
            Capsule()
                .fill(Color.lamiera)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.inchiostroTenue)
                        .frame(width: spazio.size.width * restante)
                }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Si chiude da solo")
        .accessibilityValue("\(Int((restante * NoticeText.duration).rounded(.up))) secondi")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
