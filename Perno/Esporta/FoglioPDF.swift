import SwiftUI
import UIKit
import PernoCore

// Esporta in PDF una sessione (Dettaglio sessione) o una scheda (editor), con lo stesso formato:
// foglio A4 bianco da stampare. Il contenuto lo prepara `PrintSheet` in PernoCore; qui si disegna.

// MARK: - Dai dati al foglio

extension WorkoutSession {
    @MainActor
    var foglioDaStampare: PrintSheet {
        let fine = endedAt ?? fineRegistrata
        let esercizi = orderedExercises.enumerated().map { indice, esercizio -> PrintExercise in
            let set = esercizio.orderedSets
            let numeri = SessionText.numbers(set.map(\.kind))
            let lavoro = set.filter { $0.kind != .approach }.count
            let obiettivo = PrintText.repsTarget(min: esercizio.repsMin, max: esercizio.repsMax)
            let percentuali = Approach.percentages(count: esercizio.approachCount)
            let righe = set.enumerated().map { posizione, riga -> PrintRow in
                let numero = numeri[posizione]
                let traguardo = riga.kind == .approach
                    ? (numero - 1 < percentuali.count ? PrintText.percent(percentuali[numero - 1]) : "")
                    : obiettivo
                guard let obiettivoSecondi = riga.targetSeconds else {
                    return PrintText.sessionRow(kind: riga.kind, number: numero, target: traguardo,
                                                done: riga.isDone,
                                                weight: riga.weight.map { Units.show($0) },
                                                reps: riga.reps, reserve: riga.reserve)
                }
                // Set a tempo (UI v5): obiettivo e durata fatta al posto delle ripetizioni.
                var fila = PrintText.sessionRow(kind: riga.kind, number: numero,
                                                target: Clock.text(Double(obiettivoSecondi)), done: riga.isDone,
                                                weight: esercizio.withWeight ? riga.weight.map { Units.show($0) } : nil,
                                                reps: nil, reserve: nil)
                if riga.isDone { fila.reps = Clock.text(Double(riga.seconds ?? obiettivoSecondi)) }
                return fila
            }
            return PrintExercise(
                number: indice + 1,
                name: esercizio.name,
                detail: EntrySummary.text(measure: esercizio.measure, sets: lavoro, repsMin: esercizio.repsMin,
                                          repsMax: esercizio.repsMax, approaches: esercizio.approachCount,
                                          seconds: esercizio.targetSeconds, withWeight: esercizio.withWeight,
                                          fixedRest: esercizio.fixedRest),
                setup: esercizio.setup.isEmpty ? nil : esercizio.setup,
                cues: Cues.split(esercizio.cues),
                note: esercizio.note.isEmpty ? nil : esercizio.note,
                rows: righe)
        }
        return PrintSheet(
            kind: "Sessione",
            title: titolo,
            lines: PrintText.sessionLines(
                when: SessionDetailText.when(start: startedAt, end: fine),
                duration: HomeText.duration(fine.timeIntervalSince(startedAt)),
                setsDone: setFatti, setsPlanned: setPrevisti,
                volume: HomeText.volume(Units.unit.fromKilograms(chiliSollevati)),
                unit: Units.unit.symbol),
            exercises: esercizi,
            note: note.isEmpty ? nil : note,
            footer: PrintText.footer(exportedAt: .now))
    }
}

extension Routine {
    @MainActor
    var foglioDaStampare: PrintSheet {
        let voci = orderedEntries
        let riassunto = RoutineSummary.editorLine(voci.map {
            RoutineSummary.Entry(sets: $0.setCount, approaches: $0.approachCount, fixedRest: $0.fixedRest)
        }, weekdays: planDays.map(\.weekday))
        let esercizi = voci.enumerated().map { indice, voce in
            PrintExercise(
                number: indice + 1,
                name: voce.exercise?.name ?? "Esercizio",
                detail: EntrySummary.text(measure: voce.measure, sets: voce.setCount, repsMin: voce.repsMin,
                                          repsMax: voce.repsMax, approaches: voce.approachCount,
                                          seconds: voce.targetSeconds, withWeight: voce.withWeight,
                                          fixedRest: voce.fixedRest),
                setup: voce.setup.isEmpty ? nil : voce.setup,
                cues: Cues.split(voce.cues),
                note: nil,
                rows: voce.isTimed
                    ? PrintText.routineRows(sets: voce.setCount, repsMin: 0, repsMax: 0, approaches: 0).map {
                        var fila = $0
                        fila.target = Clock.text(Double(voce.targetSeconds))
                        return fila
                    }
                    : PrintText.routineRows(sets: voce.setCount, repsMin: voce.repsMin, repsMax: voce.repsMax,
                                            approaches: voce.approachCount))
        }
        return PrintSheet(kind: "Scheda", title: name.isEmpty ? "Scheda" : name, lines: [riassunto],
                          exercises: esercizi, note: nil, footer: PrintText.footer(exportedAt: .now))
    }
}

// MARK: - Disegno

/// Disegna un `PrintSheet` su pagine A4 e lo salva in un file temporaneo da condividere.
enum FoglioPDF {
    private static let pagina = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private static let margine: CGFloat = 48
    private static let altezzaRiga: CGFloat = 22
    /// Larghezze relative delle colonne: Set, Obiettivo, Peso, Ripetizioni, Riserva.
    private static let colonne: [CGFloat] = [0.16, 0.22, 0.22, 0.22, 0.18]

    // Colori del Design System nel tema chiaro (la carta è sempre bianca).
    private static let inchiostro = UIColor(hex: 0x1C2226)
    private static let tenue = UIColor(hex: 0x566069)
    private static let linea = UIColor(hex: 0xC9D0D5)
    private static let fondoTabella = UIColor(hex: 0xECEFF1)

    private static func barlow(_ size: CGFloat) -> UIFont {
        UIFont(name: "BarlowCondensed-SemiBold", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    static func crea(_ foglio: PrintSheet, nomeFile: String) throws -> URL {
        let cartella = FileManager.default.temporaryDirectory.appendingPathComponent("Esporta", isDirectory: true)
        try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        let url = cartella.appendingPathComponent(nomeFile)
        let formato = UIGraphicsPDFRendererFormat()
        formato.documentInfo = [kCGPDFContextTitle as String: foglio.title,
                                kCGPDFContextCreator as String: "Perno"]
        let renderer = UIGraphicsPDFRenderer(bounds: pagina, format: formato)
        try renderer.writePDF(to: url) { contesto in
            var disegno = Disegno(contesto: contesto, foglio: foglio)
            disegno.tutto()
        }
        return url
    }

    /// Stato del disegno: posizione verticale e numero di pagina.
    private struct Disegno {
        let contesto: UIGraphicsPDFRendererContext
        let foglio: PrintSheet
        var y: CGFloat = 0
        var numeroPagina = 0

        var larghezza: CGFloat { pagina.width - 2 * margine }
        var fondo: CGFloat { pagina.height - margine - 24 }

        init(contesto: UIGraphicsPDFRendererContext, foglio: PrintSheet) {
            self.contesto = contesto
            self.foglio = foglio
        }

        mutating func tutto() {
            nuovaPagina()
            testo(foglio.kind.uppercased(), font: .systemFont(ofSize: 10, weight: .semibold), colore: tenue,
                  spazioDopo: 2, crenatura: 1.2)
            testo(foglio.title, font: barlow(34), colore: inchiostro, spazioDopo: 4)
            for riga in foglio.lines {
                testo(riga, font: .systemFont(ofSize: 11), colore: tenue, spazioDopo: 2)
            }
            y += 14
            filetto()
            y += 18
            for esercizio in foglio.exercises {
                disegna(esercizio)
            }
            if let nota = foglio.note {
                assicura(60)
                testo("Nota", font: .systemFont(ofSize: 12, weight: .semibold), colore: inchiostro, spazioDopo: 4)
                testo(nota, font: .systemFont(ofSize: 11), colore: inchiostro, spazioDopo: 0)
            }
            piePagina()
        }

        // MARK: Pagine

        mutating func nuovaPagina() {
            if numeroPagina > 0 { piePagina() }
            contesto.beginPage()
            numeroPagina += 1
            y = margine
        }

        /// Va a pagina nuova se non c'è spazio per `altezza`.
        mutating func assicura(_ altezza: CGFloat) {
            if y + altezza > fondo { nuovaPagina() }
        }

        func piePagina() {
            let stile: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: tenue]
            let yPie = pagina.height - margine
            (foglio.footer as NSString).draw(at: CGPoint(x: margine, y: yPie), withAttributes: stile)
            let numero = "\(numeroPagina)" as NSString
            let misura = numero.size(withAttributes: stile)
            numero.draw(at: CGPoint(x: pagina.width - margine - misura.width, y: yPie), withAttributes: stile)
        }

        // MARK: Elementi

        mutating func testo(_ stringa: String, font: UIFont, colore: UIColor, spazioDopo: CGFloat,
                            crenatura: CGFloat = 0, rientro: CGFloat = 0) {
            let paragrafo = NSMutableParagraphStyle()
            paragrafo.lineBreakMode = .byWordWrapping
            let attributi: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colore,
                                                            .kern: crenatura, .paragraphStyle: paragrafo]
            let testo = NSAttributedString(string: stringa, attributes: attributi)
            let area = CGSize(width: larghezza - rientro, height: .greatestFiniteMagnitude)
            let altezza = ceil(testo.boundingRect(with: area, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                  context: nil).height)
            assicura(altezza)
            testo.draw(with: CGRect(x: margine + rientro, y: y, width: area.width, height: altezza),
                       options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += altezza + spazioDopo
        }

        func filetto() {
            let percorso = UIBezierPath()
            percorso.move(to: CGPoint(x: margine, y: y))
            percorso.addLine(to: CGPoint(x: pagina.width - margine, y: y))
            linea.setStroke()
            percorso.lineWidth = 0.75
            percorso.stroke()
        }

        mutating func disegna(_ esercizio: PrintExercise) {
            // Intestazione dell'esercizio e almeno l'intestazione della tabella più due righe sulla stessa pagina.
            assicura(64 + altezzaRiga * 3)
            testo("\(esercizio.number)  \(esercizio.name)", font: barlow(20), colore: inchiostro, spazioDopo: 2)
            testo(esercizio.detail, font: .systemFont(ofSize: 10.5), colore: tenue, spazioDopo: 4)
            if let regolazioni = esercizio.setup {
                testo("Regolazioni: \(regolazioni)", font: .systemFont(ofSize: 10.5), colore: inchiostro, spazioDopo: 2)
            }
            for promemoria in esercizio.cues {
                testo("· \(promemoria)", font: .systemFont(ofSize: 10.5), colore: tenue, spazioDopo: 2)
            }
            y += 6
            intestazioneTabella()
            for riga in esercizio.rows {
                if y + altezzaRiga > fondo {
                    nuovaPagina()
                    testo("\(esercizio.number)  \(esercizio.name) (continua)", font: barlow(16), colore: tenue,
                          spazioDopo: 6)
                    intestazioneTabella()
                }
                disegna(riga)
            }
            if let nota = esercizio.note {
                y += 4
                testo("Nota: \(nota)", font: .italicSystemFont(ofSize: 10.5), colore: inchiostro, spazioDopo: 0)
            }
            y += 22
        }

        mutating func intestazioneTabella() {
            let cornice = CGRect(x: margine, y: y, width: larghezza, height: altezzaRiga)
            fondoTabella.setFill()
            UIBezierPath(roundedRect: cornice, cornerRadius: 4).fill()
            celle(PrintSheet.columns(unit: Units.unit.symbol), in: cornice,
                  font: .systemFont(ofSize: 9.5, weight: .semibold), colore: tenue)
            y += altezzaRiga
        }

        mutating func disegna(_ riga: PrintRow) {
            let cornice = CGRect(x: margine, y: y, width: larghezza, height: altezzaRiga)
            let colore = riga.isApproach ? tenue : inchiostro
            celle([riga.label, riga.target, riga.weight, riga.reps, riga.reserve], in: cornice,
                  font: .systemFont(ofSize: 11, weight: riga.isApproach ? .regular : .medium), colore: colore)
            let percorso = UIBezierPath()
            percorso.move(to: CGPoint(x: cornice.minX, y: cornice.maxY))
            percorso.addLine(to: CGPoint(x: cornice.maxX, y: cornice.maxY))
            linea.setStroke()
            percorso.lineWidth = 0.5
            percorso.stroke()
            y += altezzaRiga
        }

        func celle(_ valori: [String], in cornice: CGRect, font: UIFont, colore: UIColor) {
            let stile: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colore]
            var x = cornice.minX + 8
            for (indice, valore) in valori.enumerated() where indice < colonne.count {
                let larghezzaColonna = cornice.width * colonne[indice]
                let misura = (valore as NSString).size(withAttributes: stile)
                (valore as NSString).draw(
                    in: CGRect(x: x, y: cornice.midY - misura.height / 2, width: larghezzaColonna - 8, height: misura.height),
                    withAttributes: stile)
                x += larghezzaColonna
            }
        }
    }
}

// MARK: - Condivisione

/// File pronto da condividere (Salva su File, Stampa, AirDrop, Mail…).
struct FileDaCondividere: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Foglio di condivisione di sistema per un file.
struct FoglioCondivisione: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
