import SwiftUI
import SwiftData
import PernoCore

/// J Esercizio nella scheda (foglio): set, ripetizioni da/a, avvicinamento, recupero,
/// regolazioni, promemoria, «Togli dalla scheda», «Salva». La X chiude senza salvare.
struct EsercizioSchedaView: View {
    let entry: RoutineEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var sets: Int
    @State private var repsMin: Int
    @State private var repsMax: Int
    @State private var approaches: Int
    @State private var fixedRest: Double?
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
        _fixedRest = State(initialValue: entry.fixedRest)
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
    private var recuperoAbituale: Double? {
        let durate = (esercizio?.sessionExercises ?? [])
            .flatMap(\.pauses)
            .filter { $0.kind == .rest && !$0.afterApproach }
            .sorted { $0.start < $1.start }
            .map(\.duration)
        return SessionStats.usualRest(restDurations: durate)
    }

    var body: some View {
        Foglio(titolo: esercizio?.name ?? "Esercizio", sottotitolo: sottotitolo, pulsante: "Salva",
               chiudi: { dismiss() }, conferma: salva) {
            setDiLavoro
            avvicinamento
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

    private var recupero: some View {
        VStack(spacing: 12) {
            EtichettaSezione("Recupero")
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
                    VocePila(titolo: "Dai tuoi tempi", sottotitolo: testoRecuperoAbituale)
                }
                .buttonStyle(.plain)
            }
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
        entry.approachCount = approaches
        entry.fixedRest = fixedRest
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
