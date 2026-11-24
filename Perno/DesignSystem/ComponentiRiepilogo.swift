import SwiftUI
import PernoCore

// Componenti condivisi da Riepilogo e Dettaglio sessione.

// MARK: - Numero grande

/// Numero grande del riepilogo: Barlow 40, etichetta sotto ed eventuale variazione («+2%»).
struct NumeroGrande: View {
    let valore: String
    let etichetta: String
    var variazione: String? = nil

    var body: some View {
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
}

// MARK: - Barra del tempo

/// «Tempo»: barra con riscaldamento (arancio), lavoro (grafite), recupero (blu), cambi (grigio) e legenda.
struct BarraTempo: View {
    let tempi: TimeBreakdown

    var body: some View {
        let frazioni = SessionSummary.fractions(tempi)
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
                            .fill(Self.colore(parte))
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
                            .fill(Self.colore(parte))
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
    }

    static func colore(_ parte: SessionSummary.TimePart) -> Color {
        switch parte {
        case .warmUp: return .riscaldamento
        case .work: return .piastra
        case .rest: return .recupero
        case .changeover: return .piastraTenue
        }
    }
}

// MARK: - Fila che va a capo

/// Elementi in fila che vanno a capo quando non c'è più spazio (piastrine dei set nel dettaglio).
struct FilaACapo: Layout {
    var spazio: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let righe = disponi(larghezza: proposal.width ?? .infinity, subviews: subviews)
        let altezza = righe.reduce(0) { $0 + $1.altezza } + CGFloat(max(0, righe.count - 1)) * spazio
        let larghezza = righe.map(\.larghezza).max() ?? 0
        return CGSize(width: proposal.width ?? larghezza, height: altezza)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for riga in disponi(larghezza: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for indice in riga.indici {
                let misura = subviews[indice].sizeThatFits(.unspecified)
                subviews[indice].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(misura))
                x += misura.width + spazio
            }
            y += riga.altezza + spazio
        }
    }

    private struct Riga {
        var indici: [Int] = []
        var larghezza: CGFloat = 0
        var altezza: CGFloat = 0
    }

    private func disponi(larghezza: CGFloat, subviews: Subviews) -> [Riga] {
        var righe: [Riga] = []
        var corrente = Riga()
        for indice in subviews.indices {
            let misura = subviews[indice].sizeThatFits(.unspecified)
            let serve = corrente.indici.isEmpty ? misura.width : corrente.larghezza + spazio + misura.width
            if !corrente.indici.isEmpty && serve > larghezza {
                righe.append(corrente)
                corrente = Riga()
            }
            corrente.larghezza = corrente.indici.isEmpty ? misura.width : corrente.larghezza + spazio + misura.width
            corrente.altezza = max(corrente.altezza, misura.height)
            corrente.indici.append(indice)
        }
        if !corrente.indici.isEmpty { righe.append(corrente) }
        return righe
    }
}
