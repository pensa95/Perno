import SwiftUI
import PernoCore

/// Scaletta (tavola 9): fatti, adesso, «Da fare» (tieni premuto per spostare), «Rimandati» con
/// «Fai dopo questo», «Aggiungi esercizio». Vale solo per oggi: la scheda non cambia.
struct ScalettaView: View {
    let sessione: SessioneInCorso

    @Environment(\.dismiss) private var dismiss
    @State private var aggiungiAperto = false

    var body: some View {
        let scaletta = sessione.scaletta
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scaletta")
                        .font(.piastra(32))
                        .foregroundStyle(Color.inchiostro)
                    Text(LineupText.subtitle(routine: sessione.sessione.routineName))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
                Spacer()
                PulsanteTondo(icona: "xmark", etichetta: "Chiudi") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)

            List {
                ForEach(scaletta.done, id: \.self) { indice in
                    fatto(indice).riga(sopra: 2, sotto: 2)
                }
                if let corrente = scaletta.current {
                    adesso(corrente).riga(sopra: 2, sotto: 2)
                }

                if !scaletta.upcoming.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Da fare")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        if scaletta.upcoming.count > 1 {
                            Text("Tieni premuto per spostare")
                                .font(.footnote.weight(.medium))
                        }
                    }
                    .foregroundStyle(Color.inchiostroTenue)
                    .padding(.horizontal, 4)
                    .riga(sopra: 18, sotto: 10)

                    ForEach(scaletta.upcoming, id: \.self) { indice in
                        daFare(indice).riga(sopra: 2, sotto: 2)
                    }
                    .onMove { origine, destinazione in
                        sessione.riordina(scaletta.movingUpcoming(from: origine, to: destinazione))
                    }
                }

                if !scaletta.postponed.isEmpty {
                    EtichettaSezione("Rimandati")
                        .riga(sopra: 18, sotto: 10)
                    ForEach(scaletta.postponed, id: \.self) { indice in
                        rimandato(indice).riga(sopra: 2, sotto: 2)
                    }
                }

                Button {
                    aggiungiAperto = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Aggiungi esercizio")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(Color.inchiostro)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .riga(sopra: 20, sotto: 32)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
        }
        .stileFoglio()
        .presentationDetents([.large])
        .sheet(isPresented: $aggiungiAperto) {
            AggiungiEserciziView(sessione: sessione)
        }
    }

    // MARK: Righe

    private func avanzamento(_ indice: Int) -> String {
        let conto = sessione.setDiLavoro(di: indice)
        return LineupText.progress(done: conto.fatti, total: conto.totale)
    }

    private func fatto(_ indice: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.piastraFatta)
                .frame(width: 22, height: 22)
                .background(Color.inchiostro, in: Circle())
            Text(sessione.esercizi[indice].name)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(avanzamento(indice))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .background(Color.piastraFatta, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func adesso(_ indice: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.perno).frame(width: 21, height: 21)
                Circle().fill(Color.suPerno).frame(width: 6, height: 6)
            }
            .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(sessione.esercizi[indice].name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.piastraTesto)
                Text("Adesso")
                    .font(.footnote)
                    .foregroundStyle(Color.piastraTenue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(avanzamento(indice))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.piastraTenue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 64)
        .background(Color.piastra, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func daFare(_ indice: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "equal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.iconaTenue)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(sessione.esercizi[indice].name)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(LineupText.sets(sessione.setDiLavoro(di: indice).totale))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rimandato(_ indice: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sessione.esercizi[indice].name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Text(LineupText.postponed(at: sessione.rimandatiAlle[indice]))
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                sessione.faiDopoQuesto(indice)
            } label: {
                Text("Fai dopo questo")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color.foglio, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.inchiostro.opacity(0.1), lineWidth: 1)
                    }
            }
            .buttonStyle(.borderless)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.inchiostro.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
    }
}

private extension View {
    /// Riga della lista senza fondo né separatori, con i margini del foglio.
    func riga(sopra: CGFloat, sotto: CGFloat) -> some View {
        self
            .listRowInsets(EdgeInsets(top: sopra, leading: 20, bottom: sotto, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
