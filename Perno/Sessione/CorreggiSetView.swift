import SwiftUI
import PernoCore

/// Correggi set (tavola 8): peso e ripetizioni in due blocchi grandi con −/+ (tocco sul numero =
/// tastierino), «Altri dettagli» chiuso con tipo di set e riserva, «Salva» giallo, «Elimina set» rosso.
/// La X chiude senza salvare. Su un set da fare (anche quello di adesso) cambia l'obiettivo:
/// niente riserva né «Elimina set».
struct CorreggiSetView: View {
    let sessione: SessioneInCorso
    let esercizio: Int
    let indice: Int

    @Environment(\.dismiss) private var dismiss
    @State private var peso: Double
    @State private var ripetizioni: Int
    @State private var tipo: SetKind
    @State private var riserva: Reserve?
    @State private var altriDettagli = false
    @State private var scriviPeso = false
    @State private var scriviRipetizioni = false
    @State private var testo = ""
    @State private var chiediEliminazione = false

    private let passo = PlateStep.standard

    init(sessione: SessioneInCorso, esercizio: Int, indice: Int) {
        self.sessione = sessione
        self.esercizio = esercizio
        self.indice = indice
        let set = sessione.set[esercizio][indice]
        _peso = State(initialValue: set.weight ?? set.targetWeight)
        _ripetizioni = State(initialValue: set.reps ?? set.targetReps)
        _tipo = State(initialValue: set.kind)
        _riserva = State(initialValue: set.reserve)
    }

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
                        blocco(titolo: "Peso, kg", valore: Weights.format(peso),
                               meno: "Meno \(Weights.format(passo)) kg", piu: "Più \(Weights.format(passo)) kg",
                               menoAttivo: peso > SetCorrection.weights.lowerBound,
                               piuAttivo: peso < SetCorrection.weights.upperBound,
                               tocco: {
                                   testo = Weights.format(peso)
                                   scriviPeso = true
                               },
                               cambia: { verso in peso = SetCorrection.stepWeight(peso, by: verso * passo) })
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
                                  tipo: tipo, riserva: riserva)
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
        .alert("Peso, kg", isPresented: $scriviPeso) {
            TextField("Peso", text: $testo)
                .keyboardType(.decimalPad)
            Button("Annulla", role: .cancel) {}
            Button("OK") {
                if let valore = SetCorrection.parseWeight(testo) { peso = valore }
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
        Button(action: azione) {
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

    // MARK: Altri dettagli

    private var dettagli: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { altriDettagli.toggle() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Altri dettagli")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inchiostro)
                        Text(SetCorrection.details(kind: tipo, reserve: fatto ? riserva : nil))
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
                EtichettaSezione("Tipo di set")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                    ForEach(SetKind.allCases, id: \.self) { valore in
                        Scelta(titolo: valore.label, scelta: valore == tipo, altezza: 44, riempi: true) {
                            tipo = valore
                        }
                    }
                }
                if fatto {
                    EtichettaSezione("Quante ne avevi ancora?")
                    HStack(spacing: 6) {
                        ForEach(Reserve.allCases, id: \.self) { valore in
                            Scelta(titolo: valore.label, scelta: valore == riserva, altezza: 44, riempi: true) {
                                riserva = riserva == valore ? nil : valore
                            }
                        }
                    }
                }
            }
        }
    }
}
