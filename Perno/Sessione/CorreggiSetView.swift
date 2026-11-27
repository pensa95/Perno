import SwiftUI
import PernoCore

/// Correggi set (tavola 10, UI v6): peso e ripetizioni in due blocchi grandi con −/+ (tocco sul numero =
/// tastierino), «Com'è andato?» con le faccine (solo set di lavoro fatti, anche a tempo), «Tipo di set»
/// che si apre al tocco, «Salva» giallo, «Elimina set» rosso. La X chiude senza salvare. Su un set da fare
/// (anche quello di adesso) cambia l'obiettivo: niente faccine né «Elimina set». Set a tempo (UI v5): peso
/// (solo con «Con peso») e durata, a passi di 5 s.
struct CorreggiSetView: View {
    let sessione: SessioneInCorso
    let esercizio: Int
    let indice: Int

    @Environment(\.dismiss) private var dismiss
    @State private var peso: Double
    @State private var ripetizioni: Int
    @State private var tipo: SetKind
    @State private var faccina: Feeling?
    @State private var altriDettagli = false
    @State private var scriviPeso = false
    @State private var scriviRipetizioni = false
    @State private var testo = ""
    @State private var chiediEliminazione = false
    @State private var secondi: Int
    @State private var scriviSecondi = false

    private let passo = PlateStep.current

    init(sessione: SessioneInCorso, esercizio: Int, indice: Int) {
        self.sessione = sessione
        self.esercizio = esercizio
        self.indice = indice
        let set = sessione.set[esercizio][indice]
        _peso = State(initialValue: set.weight ?? set.targetWeight)
        _ripetizioni = State(initialValue: set.reps ?? set.targetReps)
        _tipo = State(initialValue: set.kind)
        _faccina = State(initialValue: set.feeling)
        _secondi = State(initialValue: set.seconds ?? sessione.obiettivoSecondi(set))
    }

    private var aTempo: Bool { sessione.aTempo(esercizio) }
    private var conPeso: Bool { !aTempo || sessione.esercizi[esercizio].withWeight }

    private var set: SessionSet { sessione.set[esercizio][indice] }

    /// Set già fatto (correzione dei valori) o da fare (obiettivo).
    private var fatto: Bool { sessione.macchina.isDone(exercise: esercizio, set: indice) }

    private var nome: String {
        let numeri = SessionText.numbers(sessione.set[esercizio].map(\.kind))
        return SessionText.shortName(set.kind, numeri[indice])
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nome)
                        .font(.piastra(32))
                        .foregroundStyle(Color.inchiostro)
                    Text(fatto
                         ? SetCorrection.subtitle(exercise: sessione.esercizi[esercizio].name,
                                                  duration: set.setDuration)
                         : SetCorrection.targetSubtitle(exercise: sessione.esercizi[esercizio].name))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                Spacer()
                PulsanteTondo(icona: "xmark", etichetta: "Chiudi senza salvare") { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        if conPeso {
                        blocco(titolo: "Peso, \(Units.unit.symbol)", valore: Units.show(peso),
                               meno: "Meno \(Weights.format(Units.step)) \(Units.unit.symbol)",
                               piu: "Più \(Weights.format(Units.step)) \(Units.unit.symbol)",
                               menoAttivo: peso > SetCorrection.weights.lowerBound,
                               piuAttivo: peso < SetCorrection.weights.upperBound,
                               tocco: {
                                   testo = Units.show(peso)
                                   scriviPeso = true
                               },
                               cambia: { verso in peso = SetCorrection.stepWeight(peso, by: verso * passo) })
                        }
                        if aTempo {
                            blocco(titolo: "Durata", valore: Clock.text(Double(secondi)),
                                   meno: "Cinque secondi in meno", piu: "Cinque secondi in più",
                                   menoAttivo: secondi > DurationLimits.range.lowerBound,
                                   piuAttivo: secondi < DurationLimits.range.upperBound,
                                   tocco: {
                                       testo = Clock.text(Double(secondi))
                                       scriviSecondi = true
                                   },
                                   cambia: { verso in secondi = DurationLimits.stepped(secondi, by: Int(verso)) })
                        } else {
                        blocco(titolo: "Ripetizioni", valore: "\(ripetizioni)",
                               meno: "Una ripetizione in meno", piu: "Una ripetizione in più",
                               menoAttivo: ripetizioni > EntryLimits.reps.lowerBound,
                               piuAttivo: ripetizioni < EntryLimits.reps.upperBound,
                               tocco: {
                                   testo = "\(ripetizioni)"
                                   scriviRipetizioni = true
                               },
                               cambia: { verso in
                                   ripetizioni = EntryLimits.clamp(ripetizioni + Int(verso), EntryLimits.reps)
                               })
                        }
                    }
                    Text("Tocca un numero per scriverlo con il tastierino.")
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                        .padding(.leading, 4)
                        .padding(.top, -8)

                    dettagli
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            PulsanteGiallo(titolo: "Salva") {
                sessione.correggi(esercizio: esercizio, set: indice, peso: peso, ripetizioni: ripetizioni,
                                  tipo: tipo, faccina: faccina, secondi: aTempo ? secondi : nil)
                dismiss()
            }
            if fatto {
                Button {
                    chiediEliminazione = true
                } label: {
                    Text("Elimina set")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.errore)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, -8)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .stileFoglio()
        .presentationDetents([.large])
        .alert("Peso, \(Units.unit.symbol)", isPresented: $scriviPeso) {
            TextField("Peso", text: $testo)
                .keyboardType(.decimalPad)
            Button("Annulla", role: .cancel) {}
            Button("OK") {
                if let valore = SetCorrection.parseWeight(testo) { peso = valore }
            }
        }
        .alert("Durata", isPresented: $scriviSecondi) {
            TextField("0:45", text: $testo)
                .keyboardType(.numbersAndPunctuation)
            Button("Annulla", role: .cancel) {}
            Button("OK") {
                if let valore = TimedText.parse(testo) { secondi = valore }
            }
        }
        .alert("Ripetizioni", isPresented: $scriviRipetizioni) {
            TextField("Ripetizioni", text: $testo)
                .keyboardType(.numberPad)
            Button("Annulla", role: .cancel) {}
            Button("OK") {
                if let valore = SetCorrection.parseReps(testo) { ripetizioni = valore }
            }
        }
        .confirmationDialog("Eliminare \(nome)?", isPresented: $chiediEliminazione, titleVisibility: .visible) {
            Button("Elimina set", role: .destructive) {
                sessione.eliminaSet(esercizio: esercizio, set: indice)
                dismiss()
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Il set torna da fare.")
        }
    }

    // MARK: Blocchi

    private func blocco(titolo: String, valore: String, meno: String, piu: String,
                        menoAttivo: Bool, piuAttivo: Bool,
                        tocco: @escaping () -> Void, cambia: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 8) {
            Text(titolo)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inchiostroTenue)
            Button(action: tocco) {
                Text(valore)
                    .font(.piastra(48))
                    .monospacedDigit()
                    .foregroundStyle(Color.inchiostro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(titolo) \(valore)")
            .accessibilityHint("Scrivi con il tastierino")
            HStack(spacing: 4) {
                tasto("minus", etichetta: meno, attivo: menoAttivo) { cambia(-1) }
                tasto("plus", etichetta: piu, attivo: piuAttivo) { cambia(1) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tasto(_ icona: String, etichetta: String, attivo: Bool, azione: @escaping () -> Void) -> some View {
        Button(action: { Aptica.tick(piu: icona == "plus"); azione() }) {
            Image(systemName: icona)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.lamiera, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!attivo)
        .opacity(attivo ? 1 : 0.3)
        .accessibilityLabel(etichetta)
    }

    // MARK: Com'è andato? e Tipo di set

    private var dettagli: some View {
        VStack(alignment: .leading, spacing: 12) {
            // «Com'è andato?» sopra «Tipo di set» (tavola 10): solo set di lavoro già fatti.
            if fatto && tipo != .approach {
                SceltaFaccina(scelta: faccina) { scelta in
                    faccina = faccina == scelta ? nil : scelta
                }
                .padding(.bottom, 8)
            }
            Button {
                withAnimation(.snappy) { altriDettagli.toggle() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tipo di set")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inchiostro)
                        Text(SetCorrection.details(kind: tipo, reserve: nil))
                            .font(.footnote)
                            .foregroundStyle(Color.inchiostroTenue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inchiostroTenue)
                        .rotationEffect(.degrees(altriDettagli ? 180 : 0))
                }
                .vocePila()
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(altriDettagli ? .isSelected : [])

            if altriDettagli {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                    ForEach(SetKind.allCases, id: \.self) { valore in
                        Scelta(titolo: valore.label, scelta: valore == tipo, altezza: 44, riempi: true) {
                            tipo = valore
                        }
                    }
                }
            }
        }
    }
}
