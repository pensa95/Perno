import SwiftUI
import PernoCore

/// Icona del gruppo muscolare (D8): omino con la zona piena. Sagoma in inchiostro chiaro (18% nel chiaro, 22%
/// nello scuro), gruppo in inchiostro pieno. Il colore lo dà chi la usa; nascosta a VoiceOver (la riga legge
/// il nome del gruppo). Misure: 28 pt nelle righe di Libreria, Aggiungi esercizi e Sostituisci (24 se stretto).
struct IconaGruppo: View {
    let gruppo: MuscleGroup
    var dimensione: CGFloat = 28
    var colore: Color = .inchiostro
    @Environment(\.colorScheme) private var schema

    var body: some View {
        Canvas { contesto, misura in
            let scala = misura.width / CGFloat(MuscleGroupIcon.grid)
            let trasformazione = CGAffineTransform(scaleX: scala, y: scala)
            func traccia(_ zone: [String]) -> Path {
                var unito = Path()
                for nome in zone {
                    if let svg = MuscleGroupIcon.zones[nome] { unito.addPath(Path.daSVG(svg)) }
                }
                return unito.applying(trasformazione)
            }
            contesto.fill(traccia(MuscleGroupIcon.silhouette(for: gruppo)),
                          with: .color(colore.opacity(schema == .dark ? 0.22 : 0.18)))
            contesto.fill(traccia(MuscleGroupIcon.highlighted(for: gruppo)), with: .color(colore))
        }
        .frame(width: dimensione, height: dimensione)
        .accessibilityHidden(true)
    }
}

extension Path {
    /// Path da un tracciato SVG con soli comandi assoluti M, L, H, V, C e Z (come quelli delle icone).
    static func daSVG(_ svg: String) -> Path {
        var percorso = Path()
        let pezzi = svg.split(separator: " ").map(String.init)
        var indice = 0
        var corrente = CGPoint.zero
        func numero() -> CGFloat {
            defer { indice += 1 }
            return indice < pezzi.count ? CGFloat(Double(pezzi[indice]) ?? 0) : 0
        }
        var comando = ""
        while indice < pezzi.count {
            if let primo = pezzi[indice].first, primo.isLetter {
                comando = pezzi[indice]
                indice += 1
                if comando == "Z" {
                    percorso.closeSubpath()
                    continue
                }
            }
            switch comando {
            case "M":
                corrente = CGPoint(x: numero(), y: numero())
                percorso.move(to: corrente)
                comando = "L" // coppie successive dopo M sono linee
            case "L":
                corrente = CGPoint(x: numero(), y: numero())
                percorso.addLine(to: corrente)
            case "H":
                corrente = CGPoint(x: numero(), y: corrente.y)
                percorso.addLine(to: corrente)
            case "V":
                corrente = CGPoint(x: corrente.x, y: numero())
                percorso.addLine(to: corrente)
            case "C":
                let c1 = CGPoint(x: numero(), y: numero())
                let c2 = CGPoint(x: numero(), y: numero())
                corrente = CGPoint(x: numero(), y: numero())
                percorso.addCurve(to: corrente, control1: c1, control2: c2)
            default:
                indice += 1
            }
        }
        return percorso
    }
}
