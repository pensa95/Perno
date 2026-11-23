import SwiftUI
import SwiftData
import PernoCore

/// K Nuovo esercizio (foglio): nome, gruppo muscolare, attrezzo; «Crea esercizio».
/// Nessuna scelta del tipo: nella v1 ogni esercizio nuovo è a pesi.
struct NuovoEsercizioView: View {
    /// Chiamata con l'esercizio appena creato (per esempio per aggiungerlo a una scheda).
    var creato: ((Exercise) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var esercizi: [Exercise]
    @State private var nome = ""
    @State private var gruppo: MuscleGroup
    @State private var attrezzo: Equipment = .machine

    init(gruppoIniziale: MuscleGroup = .chest, creato: ((Exercise) -> Void)? = nil) {
        _gruppo = State(initialValue: gruppoIniziale)
        self.creato = creato
    }

    private var controllo: ExerciseName.Check {
        ExerciseName.check(nome, existing: esercizi.map(\.name))
    }

    private var nomeValido: Bool {
        if case .valid = controllo { return true }
        return false
    }

    var body: some View {
        Foglio(titolo: "Nuovo esercizio", pulsante: "Crea esercizio", pulsanteAttivo: nomeValido,
               chiudi: { dismiss() }, conferma: crea) {
            VStack(spacing: 12) {
                EtichettaSezione("Nome")
                TextField("Nome", text: $nome)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .submitLabel(.done)
                    .padding(.horizontal, 16)
                    .frame(height: 60)
                    .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                if controllo == .duplicate {
                    Text("Esiste già un esercizio con questo nome.")
                        .font(.footnote)
                        .foregroundStyle(Color.errore)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(spacing: 12) {
                EtichettaSezione("Gruppo muscolare")
                SelettoreGriglia(valori: MuscleGroup.allCases, selezione: $gruppo) { $0.label }
            }

            VStack(spacing: 12) {
                EtichettaSezione("Attrezzo")
                SelettoreGriglia(valori: Equipment.allCases, selezione: $attrezzo) { $0.label }
                Text("Le regolazioni e il numero di set si decidono nella scheda.")
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func crea() {
        guard case let .valid(nomePulito) = controllo else { return }
        let esercizio = Exercise(name: nomePulito, muscleGroup: gruppo, equipment: attrezzo)
        context.insert(esercizio)
        try? context.save()
        creato?(esercizio)
        dismiss()
    }
}

#Preview {
    Text("Libreria")
        .sheet(isPresented: .constant(true)) {
            NuovoEsercizioView(gruppoIniziale: .legs)
        }
        .modelContainer(for: Exercise.self, inMemory: true)
}
