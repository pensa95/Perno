import SwiftUI
import UIKit
import PernoCore

/// Schermata della sessione (tavole 1–5): Riscaldamento, Cambio esercizio, 3-2-1, Set in corso, Recupero.
/// Testata, esercizio con regolazioni e promemoria, piastre dei set e dock fisso in basso.
/// Senza audio, vibrazione, notifiche e timer in background (dopo le prove tecniche sul telefono).
struct SessioneView: View {
    let sessione: SessioneInCorso
    let chiudi: () -> Void

    @State private var chiediConclusione = false
    @State private var correzione: Correzione?
    @State private var scalettaAperta = false

    /// Set fatto aperto in Correggi set.
    struct Correzione: Identifiable {
        let esercizio: Int
        let set: Int
        var id: String { "\(esercizio)-\(set)" }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { contesto in
            let ora = contesto.date
            ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            testata(ora: ora)
                            if case .warmUp = sessione.fase {
                                riscaldamento
                            } else {
                                esercizio
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    dock(ora: ora)
                }
                .ignoresSafeArea(edges: .bottom)

                if sessione.avviso != nil, let set = sessione.setDellAvviso {
                    avvisoSetFatto(set)
                }

                if case let .countdown(dal, _, _) = sessione.fase {
                    contoAllaRovescia(trascorsi: ora.timeIntervalSince(dal))
                }
            }
        }
        .background(Color.lamiera.ignoresSafeArea())
        .task(id: inizioContoAllaRovescia) {
            guard let dal = inizioContoAllaRovescia else { return }
            let fine = dal.addingTimeInterval(TimeInterval(sessione.secondiContoAllaRovescia))
            let attesa = fine.timeIntervalSinceNow
            if attesa > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            sessione.contoAllaRovesciaFinito(alle: fine)
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
        .onChange(of: sessione.conclusa) { _, conclusa in
            if conclusa { chiudi() }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $scalettaAperta) {
            ScalettaView(sessione: sessione)
        }
        .sheet(item: $correzione) { correzione in
            CorreggiSetView(sessione: sessione, esercizio: correzione.esercizio, indice: correzione.set)
        }
        .confirmationDialog("Concludere la sessione?", isPresented: $chiediConclusione, titleVisibility: .visible) {
            Button("Concludi sessione") { sessione.concludi() }
            Button("Continua", role: .cancel) {}
        }
    }

    private var inizioContoAllaRovescia: Date? {
        if case let .countdown(dal, _, _) = sessione.fase { return dal }
        return nil
    }

    // MARK: Testata

    private func testata(ora: Date) -> some View {
        HStack(spacing: 4) {
            PulsanteTondo(icona: "chevron.down", etichetta: "Riduci la sessione") {
                // Barra della sessione ridotta: con la ripresa (settimana 3).
            }
            VStack(spacing: 0) {
                Text(sessione.sessione.routineName)
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
            Button("Concludi") { chiediConclusione = true }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(width: 76, height: 44, alignment: .trailing)
                .buttonStyle(.plain)
        }
    }

    // MARK: Riscaldamento

    private var riscaldamento: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "flame")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.riscaldamento, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("Prima di cominciare")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
                    .padding(.top, 8)
                Text("Riscaldamento")
                    .font(.piastra(40))
                    .foregroundStyle(Color.inchiostro)
                Text("Cardio leggero e mobilità. Il tempo resta separato da quello degli esercizi.")
                    .font(.body)
                    .foregroundStyle(Color.inchiostroTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Poi, in ordine")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
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
            }
            .padding(.top, 24)
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
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SessionText.exerciseHeader(position: sessione.numeroEsercizio,
                                                    count: sessione.esercizi.count,
                                                    repsMin: esercizio.repsMin, repsMax: esercizio.repsMax))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                    Text(esercizio.name)
                        .font(.piastra(40))
                        .foregroundStyle(Color.inchiostro)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
                PulsanteTondo(icona: "chart.line.uptrend.xyaxis", etichetta: "Progressi") {
                    // Progressi: settimane 5–6.
                }
                PulsanteTondo(icona: "ellipsis", etichetta: "Altre azioni") {
                    // Menu «…» (nota dell'esercizio): prossimi pezzi della settimana 3.
                }
            }
            .padding(.top, 24)

            regolazioni(esercizio)

            VStack(spacing: 4) {
                ForEach(Array(sessione.set[indice].enumerated()), id: \.offset) { posizione, set in
                    Button {
                        correzione = Correzione(esercizio: indice, set: posizione)
                    } label: {
                        piastra(set, posizione: posizione, esercizio: indice)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Correggi set")
                }
            }
            .padding(.top, 16)
        }
    }

    /// Card bianca: regolazioni (più grandi durante il cambio esercizio) e promemoria.
    @ViewBuilder
    private func regolazioni(_ esercizio: SessionExercise) -> some View {
        let setup = esercizio.setup.trimmingCharacters(in: .whitespacesAndNewlines)
        let promemoria = Cues.split(esercizio.cues)
        if !setup.isEmpty || !promemoria.isEmpty {
            let inEvidenza: Bool = {
                if case .changeover = sessione.fase { return true }
                return false
            }()
            VStack(alignment: .leading, spacing: 8) {
                if !setup.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "wrench.adjustable")
                            .font(.system(size: 15, weight: .semibold))
                        Text(setup)
                            .font(.system(size: inEvidenza ? 18 : 15, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.inchiostro)
                }
                ForEach(promemoria, id: \.self) { voce in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "pin")
                            .font(.system(size: 15, weight: .semibold))
                        Text(voce)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.inchiostroTenue)
                }
            }
            .padding(inEvidenza ? 16 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 16)
        }
    }

    private func piastra(_ set: SessionSet, posizione: Int, esercizio indice: Int) -> some View {
        let numeri = SessionText.numbers(sessione.set[indice].map(\.kind))
        let numero = numeri[posizione]
        let nome = SessionText.shortName(set.kind, numero)
        let approcci = sessione.esercizi[indice].approachCount
        let prima = set.kind == .approach ? nil : sessione.prima[indice][safe: numero - 1]
        let notaPrima = prima.map { "prima " + SessionText.weightReps($0.weight, $0.reps) }

        if set.isDone, let peso = set.weight, let ripetizioni = set.reps {
            let nota = set.kind == .approach
                ? SessionText.approachPercent(number: numero, count: approcci)
                : notaPrima
            return PiastraSet(nome: nome, valore: SessionText.weightReps(peso, ripetizioni), stato: .fatta(nota: nota))
        }

        let obiettivo = SessionText.weightReps(set.targetWeight, set.targetReps)
        guard posizione == sessione.macchina.setIndex else {
            return PiastraSet(nome: nome, valore: obiettivo, stato: .daFare)
        }

        let inCorso: Bool = {
            if case .inSet = sessione.fase { return true }
            return false
        }()
        if set.kind == .approach {
            let lavoro = sessione.set[indice].first { $0.kind != .approach }?.targetWeight
            let percento = SessionText.approachPercent(number: numero, count: approcci)
            let nota = percento.map { p in lavoro.map { "\(p) di \(Weights.format($0))" } ?? p }
            return PiastraSet(nome: nome, valore: obiettivo, stato: .adesso(
                etichetta: inCorso ? "\(nome), in corso" : "\(nome), avvicinamento",
                evidenza: nil, nota: nota))
        }
        let differenza = prima.flatMap { SessionText.delta(today: set.targetWeight, before: $0.weight) }
        return PiastraSet(nome: nome, valore: obiettivo, stato: .adesso(
            etichetta: inCorso ? "\(nome), in corso" : "\(nome), obiettivo",
            evidenza: differenza, nota: notaPrima))
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
        case let .changeover(dal):
            DockSessione(
                sfondo: .piastra, coloreEtichetta: .piastraTenue, coloreTesto: .white,
                etichetta: "Cambio esercizio",
                tempo: SessionText.clock(ora.timeIntervalSince(dal)),
                secondario: sessione.puoRimandare
                    ? DockSessione.Secondario(titolo: "Rimanda", azione: { sessione.rimanda() })
                    : nil,
                principale: pulsanteInizia)
        case let .countdown(dal, inizioPausa, tipo):
            DockSessione(
                sfondo: .piastra, coloreEtichetta: .piastraTenue, coloreTesto: .white,
                etichetta: tipo == .rest ? "Recupero finito" : "Cambio esercizio",
                tempo: SessionText.clock(dal.timeIntervalSince(inizioPausa)))
        case let .inSet(dal):
            DockSessione(
                sfondo: .foglio, coloreEtichetta: .inchiostroTenue, coloreTesto: .inchiostro,
                etichetta: setCorrente(SessionText.inProgress),
                tempo: SessionText.clock(ora.timeIntervalSince(dal)),
                principale: DockSessione.Pulsante(titolo: setCorrente(SessionText.doneTitle), sfondo: .inchiostro, testo: .foglio) {
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
        return DockSessione.Pulsante(titolo: setCorrente(SessionText.startTitle),
                     dettaglio: SessionText.weightReps(set.targetWeight, set.targetReps)) {
            sessione.inizia()
        }
    }

    private func setCorrente(_ testo: (SetKind, Int) -> String) -> String {
        testo(sessione.setCorrente?.kind ?? .work, sessione.numeroSetCorrente)
    }

    // MARK: Avviso dopo «Set fatto»

    /// Sopra il dock: spunta, «Set 1, 62,5 ×», −/+ sulle ripetizioni, «Annulla» e la riserva.
    private func avvisoSetFatto(_ set: SessionSet) -> some View {
        let indice = sessione.avviso?.esercizio ?? 0
        let numeri = SessionText.numbers(sessione.set[indice].map(\.kind))
        let numero = numeri[safe: sessione.avviso?.set ?? 0] ?? 1
        let ripetizioni = set.reps ?? set.targetReps
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                Text(SessionText.noticeTitle(set.kind, numero, weight: set.weight ?? set.targetWeight))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 2) {
                    tastoRipetizioni("minus", etichetta: "Una ripetizione in meno",
                                     attivo: ripetizioni > EntryLimits.reps.lowerBound) {
                        sessione.cambiaRipetizioni(di: -1)
                    }
                    Text("\(ripetizioni)")
                        .font(.piastra(24))
                        .monospacedDigit()
                        .frame(minWidth: 22)
                    tastoRipetizioni("plus", etichetta: "Una ripetizione in più",
                                     attivo: ripetizioni < EntryLimits.reps.upperBound) {
                        sessione.cambiaRipetizioni(di: 1)
                    }
                }
                .background(Color.lamiera, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    sessione.annullaSetFatto()
                } label: {
                    Text("Annulla")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Color.lamiera, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Quante ne avevi ancora?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
                HStack(spacing: 6) {
                    ForEach(Reserve.allCases, id: \.self) { riserva in
                        let scelta = set.reserve == riserva
                        Button {
                            sessione.scegliRiserva(riserva)
                        } label: {
                            Text(riserva.label)
                                .font(.piastra(22))
                                .foregroundStyle(scelta ? Color.foglio : Color.inchiostro)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(scelta ? Color.inchiostro : Color.lamiera,
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(scelta ? .isSelected : [])
                    }
                }
            }
            .padding(.trailing, 8)
        }
        .foregroundStyle(Color.inchiostro)
        .padding(.top, 8)
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.bottom, 12)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(UIColor(hex: 0x1C2226)).opacity(0.24), radius: 16, x: 0, y: 12)
        .shadow(color: Color(UIColor(hex: 0x1C2226)).opacity(0.16), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 236)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
    }

    private func tastoRipetizioni(_ icona: String, etichetta: String, attivo: Bool,
                                  azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            Image(systemName: icona)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .disabled(!attivo)
        .opacity(attivo ? 1 : 0.35)
        .accessibilityLabel(etichetta)
    }

    // MARK: 3-2-1

    private func contoAllaRovescia(trascorsi: TimeInterval) -> some View {
        VStack(spacing: 16) {
            Text(setCorrente(SessionText.countdownTitle))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.piastraTenue)
            Text("\(SessionText.countdownValue(elapsed: trascorsi, total: sessione.secondiContoAllaRovescia))")
                .font(.piastra(140))
                .monospacedDigit()
                .foregroundStyle(Color.suPerno)
                .frame(width: 200, height: 200)
                .background(Color.perno, in: Circle())
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
