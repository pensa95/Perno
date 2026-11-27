import SwiftUI
import SwiftData
import PernoCore

/// Dettaglio sessione (tavola «L Dettaglio sessione»): «Storico» per tornare, menu «…», titolo, data
/// e orario, tre numeri (durata, set, kg con +%), barra del tempo, esercizi con avvicinamenti e set
/// come piastrine (peso × ripetizioni e riserva; set non fatti solo bordo), coppa sui record, nota.
struct DettaglioSessioneView: View {
    let sessione: WorkoutSession
    /// Nome della schermata a cui torna la freccia.
    var indietro = "Storico"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var pdf: FileDaCondividere?
    /// Letta solo per ridisegnare i pesi quando cambia l'unità.
    @AppStorage(Impostazioni.unita) private var unita: WeightUnit = .kilograms

    private var fine: Date { sessione.endedAt ?? sessione.fineRegistrata }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                testata
                titolo.padding(.top, 16)
                numeri.padding(.top, 24)
                tempo
                esercizi.padding(.top, 28)
                nota
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.lamiera.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $pdf) { file in
            FoglioCondivisione(url: file.url)
                .presentationDetents([.medium, .large])
        }
    }

    /// Senza conferma (D6): la vista si chiude e la sessione sparisce subito; il toast «Sessione eliminata ·
    /// Annulla» dura 5 s, poi si cancella davvero (così nessuna vista legge una sessione eliminata).
    private func elimina() {
        let registro = sessione
        let context = context
        dismiss()
        Eliminazioni.shared.elimina(registro, in: context)
    }

    // MARK: Testata

    private var testata: some View {
        HStack {
            PulsanteIndietro(titolo: indietro) { dismiss() }
            Spacer()
            Menu {
                Button(action: esportaPDF) {
                    Label("Esporta PDF", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive, action: elimina) {
                    Label("Elimina sessione", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.inchiostro)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Altre azioni")
            .accessibilityHint("Esporta PDF, elimina sessione")
        }
    }

    /// «Esporta PDF»: foglio da stampare della sessione, poi il foglio di condivisione.
    private func esportaPDF() {
        let nome = PrintText.fileName(title: sessione.titolo, date: sessione.startedAt)
        pdf = (try? FoglioPDF.crea(sessione.foglioDaStampare, nomeFile: nome)).map(FileDaCondividere.init)
    }

    private var titolo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sessione.titolo)
                .font(.piastra(44))
                .foregroundStyle(Color.inchiostro)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Text(SessionDetailText.when(start: sessione.startedAt, end: fine))
                .font(.subheadline)
                .foregroundStyle(Color.inchiostroTenue)
        }
    }

    // MARK: Numeri e tempo

    private var numeri: some View {
        HStack(alignment: .top, spacing: 12) {
            NumeroGrande(valore: HomeText.duration(fine.timeIntervalSince(sessione.startedAt)), etichetta: "durata")
            NumeroGrande(valore: "\(sessione.setFatti)/\(sessione.setPrevisti)", etichetta: "set")
            NumeroGrande(valore: HomeText.volume(Units.unit.fromKilograms(sessione.chiliSollevati)),
                         etichetta: Units.unit.symbol,
                         variazione: SessionSummary.volumeChange(today: sessione.chiliSollevati,
                                                                 previous: sessione.chiliVoltaScorsa))
        }
    }

    @ViewBuilder
    private var tempo: some View {
        let tempi = sessione.tempi
        if !SessionSummary.fractions(tempi).isEmpty {
            BarraTempo(tempi: tempi)
                .padding(.top, 28)
        }
    }

    // MARK: Esercizi

    private var esercizi: some View {
        let conRecord = Set(sessione.record.map(\.exercise))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Esercizi")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
            Pila {
                ForEach(sessione.orderedExercises.filter { !$0.sets.isEmpty }) { esercizio in
                    if let id = esercizio.exercise?.id {
                        NavigationLink(value: RottaStorico.esercizio(id, indietro: sessione.titolo)) {
                            card(esercizio, record: conRecord.contains(esercizio.name), freccia: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        card(esercizio, record: conRecord.contains(esercizio.name), freccia: false)
                    }
                }
            }
        }
    }

    private func card(_ esercizio: SessionExercise, record: Bool, freccia: Bool) -> some View {
        let set = esercizio.orderedSets
        let avvicinamenti = set.filter { $0.kind == .approach && $0.isDone }
            .map { (weight: $0.weight ?? $0.targetWeight, reps: $0.reps ?? $0.targetReps) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(esercizio.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if record {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Record")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Color.inchiostro)
                }
                if freccia {
                    FrecciaVoce()
                }
            }
            Text(SessionDetailText.approaches(avvicinamenti))
                .font(.footnote)
                .foregroundStyle(Color.inchiostroTenue)
            FilaACapo(spazio: 4) {
                ForEach(set.filter { $0.kind != .approach }) { voce in
                    piastrina(voce)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Set fatto: fondo chiaro pieno, «62,5 × 9» e sotto la faccina con la parola («giusto», UI v6) o, nei
    /// dati vecchi, «riserva 1». Non fatto: solo bordo, numeri tenui e «non fatto».
    private func piastrina(_ set: SessionSet) -> some View {
        let fatto = set.isDone
        let testo = set.testoValore
        let faccina = fatto ? set.feeling : nil
        let sotto = fatto ? (faccina?.word ?? SessionDetailText.reserve(set.reserve)) : SessionDetailText.notDone
        return VStack(alignment: .leading, spacing: 0) {
            Text(testo)
                .font(.piastra(20))
                .monospacedDigit()
                .foregroundStyle(fatto ? Color.inchiostro : Color.inchiostroTenue)
            if let sotto {
                HStack(spacing: 4) {
                    if let faccina {
                        Faccina(tipo: faccina, dimensione: 14, colore: .inchiostroTenue)
                    }
                    Text(sotto)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.inchiostroTenue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 64, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fatto ? Color.piastraFatta : Color.clear)
        }
        .overlay {
            if !fatto {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.inchiostro.opacity(0.22), lineWidth: 1.5)
            }
        }
    }

    // MARK: Nota

    @ViewBuilder
    private var nota: some View {
        if !sessione.note.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nota")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Text(sessione.note)
                    .font(.body)
                    .foregroundStyle(Color.inchiostro)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.top, 28)
        }
    }
}
