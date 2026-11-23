import SwiftUI
import PernoCore

/// Riepilogo di una sessione chiusa da sola (tavola «Chiusura automatica»): «Chiusa da sola» con
/// l'ora dell'ultimo set, nome e data, durata / set / kg, «Salva sessione». Nel menu «…»
/// «Elimina sessione», con conferma. Il riepilogo completo arriva nella settimana 4.
struct RiepilogoChiusaView: View {
    let sessione: WorkoutSession
    let salva: () -> Void
    let elimina: () -> Void

    @State private var chiediEliminazione = false

    private var hadSets: Bool { sessione.setFatti > 0 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Text("Riepilogo")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inchiostro)
                        HStack {
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

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.piastraTesto)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chiusa da sola")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.piastraTesto)
                            Text(AutoClose.message(end: sessione.endedAt ?? sessione.lastActivityAt, hadSets: hadSets))
                                .font(.footnote)
                                .foregroundStyle(Color.piastraTenue)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.piastra, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 16)
                    .accessibilityElement(children: .combine)

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
                    .padding(.top, 20)

                    HStack(alignment: .top, spacing: 12) {
                        numero(HomeText.duration(sessione.durata), "durata")
                        numero("\(sessione.setFatti)/\(sessione.setPrevisti)", "set")
                        numero(HomeText.volume(sessione.chiliSollevati), "kg")
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
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
    }

    private func numero(_ valore: String, _ etichetta: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valore)
                .font(.piastra(40))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(etichetta)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
