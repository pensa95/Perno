import SwiftUI
import SwiftData
import PernoCore

/// I Scegli la scheda del giorno (foglio): le schede e «Riposo». Il tocco sceglie e chiude.
/// Un giorno senza scheda è riposo.
struct PianoGiornoView: View {
    /// 1 = lunedì … 7 = domenica.
    let weekday: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var schede: [Routine]
    @Query private var giorni: [PlanDay]

    private var giorno: PlanDay? {
        giorni.first { $0.weekday == weekday }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Weekday.name(weekday))
                        .font(.piastra(32))
                        .foregroundStyle(Color.inchiostro)
                    Text("Vale da questa settimana in poi")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                Spacer()
                PulsanteTondo(icona: "xmark", etichetta: "Chiudi") { dismiss() }
            }

            ScrollView {
                Pila {
                    ForEach(schede) { scheda in
                        VoceScelta(titolo: scheda.name, sottotitolo: scheda.riassunto,
                                   scelta: giorno?.routine?.id == scheda.id) {
                            scegli(scheda)
                        }
                    }
                    VoceScelta(titolo: "Riposo", sottotitolo: "Niente in programma",
                               scelta: giorno?.routine == nil) {
                        scegli(nil)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .presentationDetents([.medium, .large])
        .stileFoglio()
    }

    private func scegli(_ scheda: Routine?) {
        if let giorno {
            giorno.routine = scheda
        } else {
            context.insert(PlanDay(weekday: weekday, routine: scheda))
        }
        try? context.save()
        dismiss()
    }
}
