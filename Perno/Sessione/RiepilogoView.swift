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
        .onAppear { notaAperta = !sessione.note.isEmpty }
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
        HStack(alignment: .top, spacing: 12) {
            numero(HomeText.duration(fine.timeIntervalSince(sessione.startedAt)), "durata")
            numero("\(sessione.setFatti)/\(sessione.setPrevisti)", "set")
            numero(HomeText.volume(sessione.chiliSollevati), "kg",
                   variazione: SessionSummary.volumeChange(today: sessione.chiliSollevati,
                                                           previous: sessione.chiliVoltaScorsa))
        }
    }

    private func numero(_ valore: String, _ etichetta: String, variazione: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valore)
                .font(.piastra(40))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                Text(etichetta)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
                if let variazione {
                    Text(variazione)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(Color.piastraFatta, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityLabel("\(variazione) sulla volta scorsa")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Set non fatti e record

    @ViewBuilder
    private var avvisi: some View {
        let nonFatti: [(esercizio: SessionExercise, conto: Int)] = completa == nil ? [] : sessione.setNonFatti
        let record = sessione.record
        if !nonFatti.isEmpty || !record.isEmpty {
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
                ForEach(Array(record.enumerated()), id: \.offset) { _, voce in
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
                }
            }
            .padding(.top, 28)
        }
    }

    // MARK: Tempo

    @ViewBuilder
    private var tempo: some View {
        let tempi = sessione.tempi
        let frazioni = SessionSummary.fractions(tempi)
        if !frazioni.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tempo")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                GeometryReader { geometria in
                    let parti = SessionSummary.TimePart.allCases.filter { (frazioni[$0] ?? 0) > 0 }
                    let spazio = geometria.size.width - CGFloat(max(0, parti.count - 1)) * 2
                    HStack(spacing: 2) {
                        ForEach(parti, id: \.self) { parte in
                            Rectangle()
                                .fill(colore(parte))
                                .frame(width: max(0, spazio * (frazioni[parte] ?? 0)))
                        }
                    }
                }
                .frame(height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .accessibilityElement()
                .accessibilityLabel(SessionSummary.accessibilityLabel(tempi))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .leading),
                                    GridItem(.flexible(), spacing: 12, alignment: .leading)],
                          alignment: .leading, spacing: 6) {
                    ForEach(SessionSummary.TimePart.allCases, id: \.self) { parte in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(colore(parte))
                                .frame(width: 8, height: 8)
                            Text(parte.label)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.inchiostroTenue)
                            Text(SessionSummary.minutes(SessionSummary.seconds(parte, in: tempi)))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.inchiostro)
                        }
                        .accessibilityHidden(true)
                    }
                }
            }
            .padding(.top, 28)
        }
    }

    private func colore(_ parte: SessionSummary.TimePart) -> Color {
        switch parte {
        case .warmUp: return .riscaldamento
        case .work: return .piastra
        case .rest: return .recupero
        case .changeover: return .piastraTenue
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
