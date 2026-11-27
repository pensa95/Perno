import SwiftUI
import PernoCore

/// Riepilogo di fine sessione (tavola «Riepilogo»): «Continua», titolo, «Elimina sessione» nel menu
/// «…», nome e data, durata / set / kg con +% sulla volta scorsa, set non fatti con «Completa» e
/// record (solo se ci sono), barra del tempo con legenda, «Aggiungi una nota», «Salva sessione».
/// Per la sessione chiusa da sola (tavola «Chiusura automatica») c'è il riquadro «Chiusa da sola»,
/// senza «Continua» né «Completa».
struct RiepilogoView: View {
    @Bindable var sessione: WorkoutSession
    /// Fine della sessione (ultimo set, «Concludi» o chiusura automatica).
    let fine: Date
    /// «Continua»: torna alla sessione; `nil` = non si può tornare (chiusa da sola).
    var continua: (() -> Void)? = nil
    /// «Completa» su un esercizio con set non fatti; `nil` = set non fatti non mostrati.
    var completa: ((SessionExercise) -> Void)? = nil
    let salva: () -> Void
    let elimina: () -> Void

    @State private var chiediEliminazione = false
    @State private var notaAperta = false
    @FocusState private var notaAttiva: Bool
    /// Riepilogo in sequenza (D7, `SummarySequence`): durata, set, kg e poi i record, ognuno quando finisce il
    /// precedente. Il progresso va da 0 al numero dei passi; un tocco lo porta subito alla fine.
    @State private var progresso: Double = 0
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    testata
                    if sessione.closedAutomatically {
                        chiusaDaSola.padding(.top, 16)
                    }
                    titolo.padding(.top, 20)
                    numeri.padding(.top, 24)
                    avvisi
                    tempo
                    nota.padding(.top, 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { salta() })
            PulsanteGiallo(titolo: "Salva sessione", azione: salva)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .background(Color.lamiera.ignoresSafeArea())
        .confirmationDialog("Eliminare la sessione?", isPresented: $chiediEliminazione, titleVisibility: .visible) {
            Button("Elimina sessione", role: .destructive, action: elimina)
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("La sessione viene eliminata con tutti i set.")
        }
        .onAppear {
            notaAperta = !sessione.note.isEmpty
            if menoMovimento {
                progresso = Double(passi)
            } else {
                withAnimation(.linear(duration: SummarySequence.duration(records: sessione.record.count))) {
                    progresso = Double(passi)
                }
            }
        }
    }

    private var passi: Int { SummarySequence.steps(records: sessione.record.count) }

    /// Un tocco salta alla fine della sequenza.
    private func salta() {
        guard progresso < Double(passi) else { return }
        var transazione = Transaction(animation: nil)
        transazione.disablesAnimations = true
        withTransaction(transazione) { progresso = Double(passi) }
    }

    // MARK: Testata

    private var testata: some View {
        ZStack {
            Text("Riepilogo")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
            HStack {
                if let continua {
                    PulsanteIndietro(titolo: "Continua", azione: continua)
                }
                Spacer()
                Menu {
                    Button(role: .destructive) {
                        chiediEliminazione = true
                    } label: {
                        Label("Elimina sessione", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Altre azioni")
            }
        }
    }

    private var chiusaDaSola: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.piastraTesto)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Chiusa da sola")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.piastraTesto)
                Text(AutoClose.message(end: fine, hadSets: sessione.setFatti > 0))
                    .font(.footnote)
                    .foregroundStyle(Color.piastraTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.piastra, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var titolo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sessione.titolo)
                .font(.piastra(44))
                .foregroundStyle(Color.inchiostro)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(ItalianDate.long(sessione.startedAt))
                .font(.subheadline)
                .foregroundStyle(Color.inchiostroTenue)
        }
    }

    // MARK: Numeri

    private var numeri: some View {
        NumeriRiepilogo(progresso: progresso,
                        secondi: fine.timeIntervalSince(sessione.startedAt),
                        setFatti: sessione.setFatti,
                        setPrevisti: sessione.setPrevisti,
                        chili: sessione.chiliSollevati,
                        variazione: SessionSummary.volumeChange(today: sessione.chiliSollevati,
                                                                previous: sessione.chiliVoltaScorsa))
    }

    // MARK: Set non fatti e record

    @ViewBuilder
    private var avvisi: some View {
        let nonFatti: [(esercizio: SessionExercise, conto: Int)] = completa == nil ? [] : sessione.setNonFatti
        let record = sessione.record
        if !nonFatti.isEmpty || !record.isEmpty {
            SequenzaRecord(progresso: progresso) { avanzamento in
            Pila {
                ForEach(Array(nonFatti.enumerated()), id: \.offset) { _, voce in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(SessionSummary.undoneTitle(exercise: voce.esercizio.name, count: voce.conto))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inchiostro)
                            Text(SessionSummary.undoneSubtitle(count: voce.conto))
                                .font(.footnote)
                                .foregroundStyle(Color.inchiostroTenue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        PulsanteSecondario(titolo: "Completa", altezza: 44, riempi: false) {
                            completa?(voce.esercizio)
                        }
                    }
                    .vocePila()
                }
                ForEach(Array(record.enumerated()), id: \.offset) { indice, voce in
                    HStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.piastraTesto)
                            .frame(width: 40, height: 40)
                            .background(Color.piastra, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voce.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inchiostro)
                            Text(voce.detail)
                                .font(.footnote)
                                .foregroundStyle(Color.inchiostroTenue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .vocePila()
                    .accessibilityElement(children: .combine)
                    .opacity(SummarySequence.fraction(progress: avanzamento,
                                                      step: SummarySequence.numberSteps + indice))
                    .offset(y: 8 * (1 - SummarySequence.fraction(progress: avanzamento,
                                                                 step: SummarySequence.numberSteps + indice)))
                }
            }
            }
            .padding(.top, 28)
        }
    }

    // MARK: Tempo

    @ViewBuilder
    private var tempo: some View {
        let tempi = sessione.tempi
        if !SessionSummary.fractions(tempi).isEmpty {
            BarraTempo(tempi: tempi)
                .padding(.top, 28)
        }
    }

    // MARK: Nota

    @ViewBuilder
    private var nota: some View {
        if notaAperta {
            TextField("Scrivi una nota", text: $sessione.note, axis: .vertical)
                .font(.body)
                .foregroundStyle(Color.inchiostro)
                .lineLimit(3...8)
                .focused($notaAttiva)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Button {
                notaAperta = true
                DispatchQueue.main.async { notaAttiva = true }
            } label: {
                HStack(spacing: 12) {
                    Text("Aggiungi una nota")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                .vocePila()
            }
            .buttonStyle(.plain)
        }
    }
}

/// Durata, set e kg che salgono contando uno dopo l'altro (C10, D7): `progresso` avanza con un'animazione e la
/// vista si ridisegna a ogni fotogramma. A fine sequenza i valori sono quelli veri.
private struct NumeriRiepilogo: View, Animatable {
    var progresso: Double
    let secondi: Double
    let setFatti: Int
    let setPrevisti: Int
    let chili: Double
    let variazione: String?

    var animatableData: Double {
        get { progresso }
        set { progresso = newValue }
    }

    var body: some View {
        let durata = SummarySequence.fraction(progress: progresso, step: 0)
        let set = SummarySequence.fraction(progress: progresso, step: 1)
        let chiliFatti = SummarySequence.fraction(progress: progresso, step: 2)
        HStack(alignment: .top, spacing: 12) {
            NumeroGrande(valore: HomeText.duration(secondi * durata), etichetta: "durata")
            NumeroGrande(valore: "\(Int((Double(setFatti) * set).rounded()))/\(setPrevisti)", etichetta: "set")
            NumeroGrande(valore: HomeText.volume(Units.unit.fromKilograms(chili * chiliFatti)),
                         etichetta: Units.unit.symbol,
                         variazione: variazione)
        }
    }
}

/// Contenitore dei record: si ridisegna a ogni fotogramma della sequenza, così ogni record compare quando
/// finisce il passo prima (D7).
private struct SequenzaRecord<Contenuto: View>: View, Animatable {
    var progresso: Double
    let contenuto: (Double) -> Contenuto

    init(progresso: Double, @ViewBuilder contenuto: @escaping (Double) -> Contenuto) {
        self.progresso = progresso
        self.contenuto = contenuto
    }

    var animatableData: Double {
        get { progresso }
        set { progresso = newValue }
    }

    var body: some View { contenuto(progresso) }
}
