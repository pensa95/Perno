import SwiftUI
import PernoCore

/// Obiettivi di oggi (UI v6, tavola 11), dalla scaletta: Set, Peso e Ripetizioni (a tempo la Durata; senza
/// «Con peso» niente peso) con −/+, la nota «Valgono per tutti i set di oggi…» e «Salva» giallo.
/// Solo per questa sessione: la scheda non cambia.
struct ObiettiviOggiView: View {
    let sessione: SessioneInCorso
    let esercizio: Int

    @Environment(\.dismiss) private var dismiss
    @State private var set: Int
    @State private var peso: Double
    @State private var ripetizioni: Int
    @State private var secondi: Int?

    init(sessione: SessioneInCorso, esercizio: Int) {
        self.sessione = sessione
        self.esercizio = esercizio
        let valori = sessione.obiettiviDiOggi(esercizio)
        _set = State(initialValue: valori?.obiettivi.sets ?? 3)
        _peso = State(initialValue: valori?.obiettivi.weight ?? 0)
        _ripetizioni = State(initialValue: valori?.obiettivi.reps ?? 8)
        _secondi = State(initialValue: valori?.secondi)
    }

    private var conPeso: Bool { secondi == nil || sessione.esercizi[esercizio].withWeight }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessione.esercizi[esercizio].name)
                        .font(.piastra(32))
                        .foregroundStyle(Color.inchiostro)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("Obiettivi di oggi, solo per questa sessione")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                Spacer()
                PulsanteTondo(icona: "xmark", etichetta: "Chiudi") { dismiss() }
            }

            HStack(spacing: 8) {
                blocco(titolo: "Set", valore: "\(set)", meno: "Un set in meno", piu: "Un set in più",
                       menoAttivo: set > EntryLimits.sets.lowerBound, piuAttivo: set < EntryLimits.sets.upperBound) {
                    set = EntryLimits.clamp(set + $0, EntryLimits.sets)
                }
                if conPeso {
                    let passo = "\(Weights.format(Units.step)) \(Units.unit.symbol)"
                    blocco(titolo: "Peso, \(Units.unit.symbol)", valore: Units.show(peso),
                           meno: "\(passo) in meno", piu: "\(passo) in più",
                           menoAttivo: peso > SetCorrection.weights.lowerBound,
                           piuAttivo: peso < SetCorrection.weights.upperBound) { verso in
                        peso = SetCorrection.stepWeight(peso, by: Double(verso) * PlateStep.current)
                    }
                }
                if let durata = secondi {
                    blocco(titolo: "Durata", valore: Clock.text(Double(durata)),
                           meno: "Cinque secondi in meno", piu: "Cinque secondi in più",
                           menoAttivo: durata > DurationLimits.range.lowerBound,
                           piuAttivo: durata < DurationLimits.range.upperBound) {
                        secondi = DurationLimits.stepped(durata, by: $0)
                    }
                } else {
                    blocco(titolo: "Ripetizioni", valore: "\(ripetizioni)",
                           meno: "Una ripetizione in meno", piu: "Una ripetizione in più",
                           menoAttivo: ripetizioni > EntryLimits.reps.lowerBound,
                           piuAttivo: ripetizioni < EntryLimits.reps.upperBound) {
                        ripetizioni = EntryLimits.clamp(ripetizioni + $0, EntryLimits.reps)
                    }
                }
            }

            Text("Valgono per tutti i set di oggi. Un singolo set lo cambi toccandolo in sessione.")
                .font(.footnote)
                .foregroundStyle(Color.inchiostroTenue)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
                .padding(.top, -8)

            Spacer(minLength: 0)

            PulsanteGiallo(titolo: "Salva") {
                sessione.impostaObiettivi(esercizio,
                                          TodayTargets(sets: set, weight: conPeso ? peso : 0,
                                                       reps: secondi == nil ? ripetizioni : 0),
                                          secondi: secondi)
                dismiss()
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .stileFoglio()
        .presentationDetents([.medium, .large])
    }

    /// Blocco con il valore a 48 pt e − / + da 56 (come in Correggi set).
    private func blocco(titolo: String, valore: String, meno: String, piu: String,
                        menoAttivo: Bool, piuAttivo: Bool, cambia: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 8) {
            Text(titolo)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inchiostroTenue)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(valore)
                .font(.piastra(48))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("\(titolo) \(valore)")
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
}
