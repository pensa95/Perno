import SwiftUI
import SwiftData
import PernoCore

/// J Esercizio nella scheda (foglio): «Si misura in» Ripetizioni / Tempo (UI v5), set, ripetizioni
/// da/a oppure durata e «Con peso», avvicinamento (solo a ripetizioni), recupero, regolazioni,
/// promemoria, «Togli dalla scheda», «Salva». La X chiude senza salvare.
struct EsercizioSchedaView: View {
    let entry: RoutineEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var sets: Int
    @State private var repsMin: Int
    @State private var repsMax: Int
    @State private var approaches: Int
    @State private var misura: SetMeasure
    @State private var secondi: Int
    @State private var conPeso: Bool
    @State private var fixedRest: Double?
    @State private var modoRecupero: RestMode
    @State private var partiDaSolo: Bool
    @State private var setup: String
    @State private var cues: [String]
    @State private var nuovoPromemoria = ""
    @State private var aggiungendo = false
    @FocusState private var promemoriaAttivo: Bool

    init(entry: RoutineEntry) {
        self.entry = entry
        _sets = State(initialValue: entry.setCount)
        _repsMin = State(initialValue: entry.repsMin)
        _repsMax = State(initialValue: entry.repsMax)
        _approaches = State(initialValue: entry.approachCount)
        _misura = State(initialValue: entry.measure)
        _secondi = State(initialValue: entry.targetSeconds)
        _conPeso = State(initialValue: entry.withWeight)
        _fixedRest = State(initialValue: entry.fixedRest)
        _modoRecupero = State(initialValue: entry.restMode)
        _partiDaSolo = State(initialValue: entry.autoStartAfterRest)
        _setup = State(initialValue: entry.setup)
        _cues = State(initialValue: Cues.split(entry.cues))
    }

    private var esercizio: Exercise? { entry.exercise }

    private var sottotitolo: String {
        var parts: [String] = []
        if let esercizio {
            parts.append("\(esercizio.muscleGroup.label), \(esercizio.equipment.label.lowercased()).")
        }
        if let scheda = entry.routine {
            parts.append("Vale per \(scheda.name)")
        }
        return parts.joined(separator: " ")
    }

    /// Recupero abituale dai recuperi registrati per questo esercizio (esclusi avvicinamenti e cambi).
    private var recuperoAbituale: Double? { esercizio?.recuperoAbituale }

    var body: some View {
        Foglio(titolo: esercizio?.name ?? "Esercizio", sottotitolo: sottotitolo, pulsante: "Salva",
               chiudi: { dismiss() }, conferma: salva) {
            siMisuraIn
            if misura == .time {
                setATempo
            } else {
                setDiLavoro
                avvicinamento
            }
            recupero
            regolazioni
            promemoria
            Button(role: .destructive, action: togli) {
                Text("Togli dalla scheda")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.errore)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Sezioni

    /// Prima voce del foglio (UI v5): l'esercizio si misura in ripetizioni o a tempo.
    private var siMisuraIn: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Si misura in")
            SelettoreSegmenti(valori: SetMeasure.allCases, selezione: $misura) { $0.label }
                .accessibilityLabel("Si misura in")
        }
    }

    /// Set di lavoro a tempo: set, durata (passi di 5 s) e spunta «Con peso».
    private var setATempo: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Set di lavoro")
            Pila {
                HStack(spacing: 12) {
                    Text("Set")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StepperPiastra(valore: "\(sets)",
                                   menoAttivo: sets > EntryLimits.sets.lowerBound,
                                   piuAttivo: sets < EntryLimits.sets.upperBound,
                                   etichettaMeno: "Un set in meno", etichettaPiu: "Un set in più",
                                   meno: { sets -= 1 }, piu: { sets += 1 })
                }
                .vocePila()

                HStack(spacing: 12) {
                    Text("Durata")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StepperPiastra(valore: Clock.text(Double(secondi)),
                                   menoAttivo: secondi > DurationLimits.range.lowerBound,
                                   piuAttivo: secondi < DurationLimits.range.upperBound,
                                   etichettaMeno: "Cinque secondi in meno", etichettaPiu: "Cinque secondi in più",
                                   meno: { secondi = DurationLimits.stepped(secondi, by: -1) },
                                   piu: { secondi = DurationLimits.stepped(secondi, by: 1) })
                }
                .vocePila()

                Button {
                    conPeso.toggle()
                } label: {
                    HStack(spacing: 12) {
                        SpuntaQuadrata(attiva: conPeso)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Con peso")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inchiostro)
                            Text(EntryHints.withWeight)
                                .font(.footnote)
                                .foregroundStyle(Color.inchiostroTenue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .vocePila()
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Con peso")
                .accessibilityValue(conPeso ? "Attivo" : "Non attivo")
                .accessibilityHint(EntryHints.withWeight)
                .accessibilityAddTraits(.isToggle)
            }
            aiuto(EntryHints.timedProgression(seconds: secondi))
        }
    }

    private var setDiLavoro: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Set di lavoro")
            Pila {
                HStack(spacing: 12) {
                    Text("Set")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StepperPiastra(valore: "\(sets)",
                                   menoAttivo: sets > EntryLimits.sets.lowerBound,
                                   piuAttivo: sets < EntryLimits.sets.upperBound,
                                   etichettaMeno: "Un set in meno", etichettaPiu: "Un set in più",
                                   meno: { sets -= 1 }, piu: { sets += 1 })
                }
                .vocePila()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ripetizioni")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text("da")
                                .font(.subheadline)
                                .foregroundStyle(Color.inchiostroTenue)
                                .frame(width: 20, alignment: .leading)
                            StepperPiastra(valore: "\(repsMin)", riempi: true,
                                           menoAttivo: repsMin > EntryLimits.reps.lowerBound,
                                           piuAttivo: repsMin < EntryLimits.reps.upperBound,
                                           etichettaMeno: "Minimo, una in meno", etichettaPiu: "Minimo, una in più",
                                           meno: { impostaMin(repsMin - 1) }, piu: { impostaMin(repsMin + 1) })
                        }
                        HStack(spacing: 6) {
                            Text("a")
                                .font(.subheadline)
                                .foregroundStyle(Color.inchiostroTenue)
                                .frame(width: 12, alignment: .leading)
                            StepperPiastra(valore: "\(repsMax)", riempi: true,
                                           menoAttivo: repsMax > EntryLimits.reps.lowerBound,
                                           piuAttivo: repsMax < EntryLimits.reps.upperBound,
                                           etichettaMeno: "Massimo, una in meno", etichettaPiu: "Massimo, una in più",
                                           meno: { impostaMax(repsMax - 1) }, piu: { impostaMax(repsMax + 1) })
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 8)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            aiuto(EntryHints.progression(repsMax: repsMax, step: Units.step, unit: Units.unit.symbol))
        }
    }

    private var avvicinamento: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Avvicinamento")
            SelettoreSegmenti(valori: Array(EntryLimits.approaches), selezione: $approaches) {
                $0 == 0 ? "Nessuno" : "\($0)"
            }
            .accessibilityLabel("Set di avvicinamento")
            if let testo = EntryHints.approach(count: approaches) {
                aiuto(testo)
            }
        }
    }

    /// Recupero (UI v6, tavole J): Cronometro / Alla rovescia, durata di partenza («Parte dai tuoi tempi»,
    /// tocco per fissarla), «Parti da solo a fine recupero» (solo alla rovescia) e la nota sul tocco in sessione.
    private var recupero: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Recupero")
            SelettoreSegmenti(valori: [RestMode.stopwatch, .countdown], selezione: $modoRecupero,
                              etichetta: { $0 == .countdown ? "Alla rovescia" : "Cronometro" })
            if let fixedRest {
                HStack(spacing: 12) {
                    Text("Fissato")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StepperPiastra(valore: Clock.text(fixedRest),
                                   menoAttivo: fixedRest > EntryLimits.rest.lowerBound,
                                   piuAttivo: fixedRest < EntryLimits.rest.upperBound,
                                   etichettaMeno: "Quindici secondi in meno",
                                   etichettaPiu: "Quindici secondi in più",
                                   meno: { cambiaRecupero(-EntryLimits.restStep) },
                                   piu: { cambiaRecupero(EntryLimits.restStep) })
                }
                .vocePila()
                Button {
                    self.fixedRest = nil
                } label: {
                    Text("Usa i tuoi tempi")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inchiostroTenue)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, -4)
            } else {
                Button {
                    self.fixedRest = SessionStats.roundedRest(recuperoAbituale ?? EntryLimits.defaultFixedRest)
                } label: {
                    VocePila(titolo: "Parte dai tuoi tempi", sottotitolo: testoRecuperoAbituale)
                }
                .buttonStyle(.plain)
            }
            if modoRecupero == .countdown {
                Interruttore(titolo: "Parti da solo a fine recupero",
                             sottotitolo: "A zero il 3-2-1 parte senza toccare",
                             acceso: $partiDaSolo)
            }
            Text("In sessione puoi cambiarlo toccando il tempo: vale solo per quella volta.")
                .font(.footnote)
                .foregroundStyle(Color.inchiostroTenue)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
                .padding(.top, -4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var testoRecuperoAbituale: String {
        if let recuperoAbituale {
            return "Di solito \(Clock.text(recuperoAbituale)). Tocca per fissarlo"
        }
        return "Ancora nessun tempo misurato. Tocca per fissarlo"
    }

    private var regolazioni: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Regolazioni")
            TextField("Sedile, schienale, maniglie", text: $setup, axis: .vertical)
                .lineLimit(2...5)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var promemoria: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Promemoria")
            Pila {
                ForEach(Array(cues.enumerated()), id: \.offset) { indice, testo in
                    HStack(spacing: 12) {
                        Text(testo)
                            .font(.body)
                            .foregroundStyle(Color.inchiostro)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            cues.remove(at: indice)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.inchiostroTenue)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Togli il promemoria")
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if aggiungendo {
                    TextField("Nuovo promemoria", text: $nuovoPromemoria)
                        .font(.body)
                        .foregroundStyle(Color.inchiostro)
                        .focused($promemoriaAttivo)
                        .submitLabel(.done)
                        .onSubmit(aggiungiPromemoria)
                        .vocePila()
                } else {
                    Button {
                        aggiungendo = true
                        promemoriaAttivo = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Aggiungi promemoria")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Color.inchiostro)
                        .vocePila()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func aiuto(_ testo: String) -> some View {
        Text(testo)
            .font(.footnote)
            .foregroundStyle(Color.inchiostroTenue)
            .padding(.leading, 4)
            .padding(.top, -4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Azioni

    private func impostaMin(_ valore: Int) {
        let range = EntryLimits.settingMin(valore, max: repsMax)
        repsMin = range.min
        repsMax = range.max
    }

    private func impostaMax(_ valore: Int) {
        let range = EntryLimits.settingMax(valore, min: repsMin)
        repsMin = range.min
        repsMax = range.max
    }

    private func cambiaRecupero(_ delta: Double) {
        guard let fixedRest else { return }
        self.fixedRest = EntryLimits.clamp(fixedRest + delta, EntryLimits.rest)
    }

    private func aggiungiPromemoria() {
        let testo = nuovoPromemoria.trimmingCharacters(in: .whitespacesAndNewlines)
        if !testo.isEmpty { cues.append(testo) }
        nuovoPromemoria = ""
        aggiungendo = false
    }

    private func salva() {
        aggiungiPromemoria()
        entry.setCount = sets
        entry.repsMin = repsMin
        entry.repsMax = repsMax
        // L'avvicinamento è in % del peso: c'è solo a ripetizioni.
        entry.approachCount = misura == .time ? 0 : approaches
        entry.measure = misura
        entry.targetSeconds = secondi
        entry.withWeight = conPeso
        entry.fixedRest = fixedRest
        entry.restMode = modoRecupero
        // «Parti da solo» vale solo alla rovescia.
        entry.autoStartAfterRest = modoRecupero == .countdown && partiDaSolo
        entry.setup = setup.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.cues = Cues.join(cues)
        try? context.save()
        dismiss()
    }

    /// Chiude il foglio e poi elimina, così nessuna vista legge un esercizio già eliminato.
    private func togli() {
        let entry = entry
        let context = context
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let scheda = entry.routine
            let rimasti = scheda?.orderedEntries.filter { $0 !== entry } ?? []
            context.delete(entry)
            for (indice, rimasto) in rimasti.enumerated() {
                rimasto.position = indice
            }
            try? context.save()
        }
    }
}

/// Spunta quadrata (v5, «Con peso»): piena in inchiostro con il segno di spunta, vuota con il bordo.
private struct SpuntaQuadrata: View {
    let attiva: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(attiva ? Color.inchiostro : Color.clear)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(attiva ? Color.clear : Color.inchiostroTenue, lineWidth: 2)
            if attiva {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.foglio)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
