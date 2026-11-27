import SwiftUI
import PernoCore

/// Faccina al tratto di «Com'è andato?» (UI v6): cerchio, occhi e bocca (sorriso, linea, broncio),
/// disegnata come le icone su una griglia di 24 con tratto 2. Tre misure: 28 nell'avviso e in Correggi set,
/// 20 sulle piastre fatte, 14 nel dettaglio sessione. Senza colore: lo dà chi la usa.
struct Faccina: View {
    let tipo: Feeling
    var dimensione: CGFloat = 28
    var colore: Color = .inchiostro

    var body: some View {
        Canvas { contesto, misura in
            let s = misura.width / 24
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            let tratto = StrokeStyle(lineWidth: 2 * s, lineCap: .round, lineJoin: .round)
            let inchiostro = GraphicsContext.Shading.color(colore)
            contesto.stroke(Path(ellipseIn: CGRect(x: 2.5 * s, y: 2.5 * s, width: 19 * s, height: 19 * s)),
                            with: inchiostro, style: tratto)
            // Occhi: punto di raggio 0,6 con il tratto intorno = 1,6.
            for x in [9.0, 15.0] {
                contesto.fill(Path(ellipseIn: CGRect(x: (x - 1.6) * s, y: (9.8 - 1.6) * s,
                                                     width: 3.2 * s, height: 3.2 * s)), with: inchiostro)
            }
            var bocca = Path()
            switch tipo {
            case .light:
                bocca.move(to: p(8, 13.5))
                bocca.addCurve(to: p(12, 16.2), control1: p(9.1, 15.3), control2: p(10.5, 16.2))
                bocca.addCurve(to: p(16, 13.5), control1: p(13.5, 16.2), control2: p(14.9, 15.3))
            case .justRight:
                bocca.move(to: p(8.5, 15))
                bocca.addLine(to: p(15.5, 15))
            case .hard:
                bocca.move(to: p(8, 16.8))
                bocca.addCurve(to: p(12, 14.1), control1: p(9.1, 15), control2: p(10.5, 14.1))
                bocca.addCurve(to: p(16, 16.8), control1: p(13.5, 14.1), control2: p(14.9, 15))
            }
            contesto.stroke(bocca, with: inchiostro, style: tratto)
        }
        .frame(width: dimensione, height: dimensione)
        .accessibilityHidden(true)
    }
}

/// «Com'è andato?»: tre scelte alte 64 (faccina e parola), la scelta in inchiostro con la faccina chiara.
/// Un secondo tocco sulla stessa la toglie. Usata nell'avviso dopo il set e in Correggi set.
struct SceltaFaccina: View {
    let scelta: Feeling?
    let scegli: (Feeling) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NoticeText.feelingQuestion)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inchiostroTenue)
                .padding(.leading, 4)
            HStack(spacing: 8) {
                ForEach(Feeling.allCases, id: \.self) { faccina in
                    let attiva = faccina == scelta
                    Button {
                        Aptica.selezione.dai()
                        scegli(faccina)
                    } label: {
                        VStack(spacing: 4) {
                            Faccina(tipo: faccina, dimensione: 28,
                                    colore: attiva ? Color.suInchiostro : Color.inchiostro)
                            Text(faccina.title)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(attiva ? Color.suInchiostro : Color.inchiostro)
                        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
                        .background(attiva ? Color.inchiostro : Color.lamiera,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(faccina.title)
                    .accessibilityAddTraits(attiva ? .isSelected : [])
                }
            }
        }
    }
}
