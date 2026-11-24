import SwiftUI
import SwiftData
import PernoCore

/// Piano settimanale (sezione a sé dal 24/11, prima era in Schede): 7 voci della pila con la scheda
/// di ogni giorno o «Riposo»; il tocco apre «Scegli la scheda del giorno».
struct PianoView: View {
    @Query private var giorni: [PlanDay]
    @State private var giornoAperto: GiornoScelto?

    private struct GiornoScelto: Identifiable {
        let weekday: Int
        var id: Int { weekday }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TestataSezione(titolo: Sezione.piano.titolo)

                Text("Tocca un giorno per cambiare scheda")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
                    .padding(.top, 12)

                Pila {
                    ForEach(Weekday.all, id: \.self) { giorno in
                        Button {
                            giornoAperto = GiornoScelto(weekday: giorno)
                        } label: {
                            voceGiorno(giorno)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $giornoAperto) { giorno in
            PianoGiornoView(weekday: giorno.weekday)
        }
    }

    private func voceGiorno(_ giorno: Int) -> some View {
        let scheda = giorni.first { $0.weekday == giorno }?.routine
        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(Weekday.name(giorno))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
                if giorno == Weekday.of(.now) {
                    Text("oggi")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.suInchiostro)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.inchiostro, in: Capsule())
                }
            }
            .frame(minWidth: 104, alignment: .leading)

            Group {
                if let scheda {
                    Text(scheda.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                } else {
                    Text("Riposo")
                        .font(.body)
                        .foregroundStyle(Color.inchiostroTenue)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)

            FrecciaVoce()
        }
        .vocePila()
    }
}

#Preview {
    NavigationStack { PianoView() }
        .modelContainer(for: Routine.self, inMemory: true)
}
