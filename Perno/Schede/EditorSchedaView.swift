import SwiftUI
import SwiftData
import PernoCore

/// J Editor scheda: nome, riepilogo, esercizi (tieni premuto per spostare, scorri a sinistra per «Rimuovi»), «Aggiungi esercizio»,
/// «Nel piano settimanale»; Duplica ed Elimina nel menu «…». Le modifiche si salvano da sole.
struct EditorSchedaView: View {
    @Bindable var scheda: Routine

    @Environment(\.dismiss) private var dismiss
    @Environment(\.apriSezione) private var apriSezione
    @Environment(\.modelContext) private var context
    @Query private var schede: [Routine]
    @State private var esercizioAperto: RoutineEntry?
    @State private var libreriaAperta = false
    @State private var confermaElimina = false
    @State private var pdf: FileDaCondividere?

    private var esercizi: [RoutineEntry] { scheda.orderedEntries }

    private var giorniNelPiano: [Int] {
        scheda.planDays.map(\.weekday)
    }

    private var riassunto: String {
        RoutineSummary.editorLine(esercizi.map {
            RoutineSummary.Entry(sets: $0.setCount, approaches: $0.approachCount, fixedRest: $0.fixedRest)
        }, weekdays: giorniNelPiano)
    }

    var body: some View {
        List {
            testata
                .riga(sopra: 8, sotto: 0)

            VStack(alignment: .leading, spacing: 4) {
                EtichettaSezione("Nome")
                TextField("Nome della scheda", text: $scheda.name)
                    .font(.piastra(32))
                    .foregroundStyle(Color.inchiostro)
                    .submitLabel(.done)
                    .padding(.horizontal, 16)
                    .frame(height: 60)
                    .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(riassunto)
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
                    .padding(.leading, 4)
                    .padding(.top, 4)
            }
            .riga(sopra: 16, sotto: 0)

            HStack(alignment: .firstTextBaseline) {
                Text("Esercizi")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Spacer()
                if esercizi.count > 1 {
                    Text("Tieni premuto per spostare")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
            }
            .padding(.horizontal, 4)
            .riga(sopra: 32, sotto: 10)

            ForEach(Array(esercizi.enumerated()), id: \.element.id) { indice, esercizio in
                Button {
                    esercizioAperto = esercizio
                } label: {
                    rigaEsercizio(esercizio, numero: indice + 1)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        rimuovi(esercizio)
                    } label: {
                        Label("Rimuovi", systemImage: "trash")
                    }
                    .tint(Color.errore)
                }
                .riga(sopra: 2, sotto: 2)
            }
            .onMove(perform: sposta)

            PulsanteGiallo(titolo: "Aggiungi esercizio", icona: "plus") {
                libreriaAperta = true
            }
            .riga(sopra: 10, sotto: 0)

            VStack(spacing: 12) {
                EtichettaSezione("Nel piano settimanale")
                Button {
                    apriSezione(.piano) // il piano si cambia dalla sezione Piano
                } label: {
                    VocePila(titolo: PlanDaysText.list(giorniNelPiano) ?? "Nessun giorno", dettaglio: "Cambia")
                }
                .buttonStyle(.plain)
            }
            .riga(sopra: 32, sotto: 32)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollDismissesKeyboard(.immediately)
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $esercizioAperto) { esercizio in
            EsercizioSchedaView(entry: esercizio)
        }
        .navigationDestination(isPresented: $libreriaAperta) {
            LibreriaView(indietro: scheda.name.isEmpty ? "Scheda" : scheda.name, scegli: aggiungi)
        }
        .confirmationDialog("Eliminare la scheda?", isPresented: $confermaElimina, titleVisibility: .visible) {
            Button("Elimina scheda", role: .destructive, action: elimina)
        } message: {
            Text("Le sessioni già fatte restano nello storico.")
        }
        .sheet(item: $pdf) { file in
            FoglioCondivisione(url: file.url)
                .presentationDetents([.medium, .large])
        }
        .onDisappear(perform: salva)
    }

    /// «Esporta PDF»: foglio da stampare della scheda (righe vuote da compilare), poi il foglio di condivisione.
    private func esportaPDF() {
        salva()
        let nome = PrintText.fileName(title: scheda.name.isEmpty ? "Scheda" : scheda.name, date: .now)
        pdf = (try? FoglioPDF.crea(scheda.foglioDaStampare, nomeFile: nome)).map(FileDaCondividere.init)
    }

    private var testata: some View {
        HStack {
            PulsanteIndietro(titolo: "Schede") { dismiss() }
            Spacer()
            Menu {
                Button("Esporta PDF", systemImage: "square.and.arrow.up", action: esportaPDF)
                Button("Duplica scheda", action: duplica)
                Button("Elimina scheda", role: .destructive) { confermaElimina = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.inchiostro)
                    .frame(width: 44, height: 44)
                    .background(Color.foglio, in: Circle())
            }
            .accessibilityLabel("Altre azioni: esporta PDF, duplica scheda, elimina scheda")
        }
    }

    private func rigaEsercizio(_ esercizio: RoutineEntry, numero: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "equal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.iconaTenue)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text("\(numero)")
                .font(.piastra(22))
                .foregroundStyle(Color.inchiostroTenue)
                .frame(minWidth: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(esercizio.exercise?.name ?? "Esercizio eliminato")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Text(EntrySummary.text(measure: esercizio.measure, sets: esercizio.setCount,
                                       repsMin: esercizio.repsMin, repsMax: esercizio.repsMax,
                                       approaches: esercizio.approachCount, seconds: esercizio.targetSeconds,
                                       withWeight: esercizio.withWeight, fixedRest: esercizio.fixedRest))
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FrecciaVoce()
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Azioni

    private func sposta(da origine: IndexSet, a destinazione: Int) {
        for (indice, esercizio) in ListOrder.move(esercizi, from: origine, to: destinazione).enumerated() {
            esercizio.position = indice
        }
        salva()
    }

    /// Nuovo esercizio in fondo, con 3 set da 8 a 12.
    private func aggiungi(_ esercizio: Exercise) {
        let entry = RoutineEntry(position: esercizi.count, exercise: esercizio)
        context.insert(entry)
        entry.routine = scheda
        salva()
    }

    /// Scorrimento a sinistra sulla card → «Rimuovi»: toglie l'esercizio dalla scheda e rinumera gli altri.
    private func rimuovi(_ esercizio: RoutineEntry) {
        let rimasti = esercizi.filter { $0 !== esercizio }
        withAnimation {
            context.delete(esercizio)
            for (indice, rimasto) in rimasti.enumerated() {
                rimasto.position = indice
            }
        }
        salva()
    }

    private func duplica() {
        let copia = Routine(name: RoutineNames.copy(of: scheda.name, existing: schede.map(\.name)))
        context.insert(copia)
        for originale in esercizi {
            let entry = RoutineEntry(position: originale.position, exercise: originale.exercise,
                                     setCount: originale.setCount, repsMin: originale.repsMin,
                                     repsMax: originale.repsMax, approachCount: originale.approachCount,
                                     fixedRest: originale.fixedRest, setup: originale.setup, cues: originale.cues,
                                     measure: originale.measure, targetSeconds: originale.targetSeconds,
                                     withWeight: originale.withWeight)
            context.insert(entry)
            entry.routine = copia
        }
        salva()
        dismiss()
    }

    /// Torna alle Schede e poi elimina, così nessuna vista legge una scheda già eliminata.
    private func elimina() {
        let scheda = scheda
        let context = context
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            context.delete(scheda)
            try? context.save()
        }
    }

    private func salva() {
        try? context.save()
    }
}

private extension View {
    /// Riga della lista senza fondo né separatori, con i margini della schermata.
    func riga(sopra: CGFloat, sotto: CGFloat) -> some View {
        self
            .listRowInsets(EdgeInsets(top: sopra, leading: 20, bottom: sotto, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
