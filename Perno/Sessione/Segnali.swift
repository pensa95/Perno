import AVFoundation
import UIKit

/// Bip e vibrazione del 3-2-1 e della fine del recupero alla rovescia («Prima di ogni set» nelle Impostazioni).
///
/// I bip di una sequenza (3, 2, 1 e il «via», più alto) sono un solo suono preparato all'inizio e messo
/// in coda tutto insieme: così suona fino in fondo anche se lo schermo si blocca o l'app va in background
/// (`UIBackgroundModes: audio` in `project.yml`; mentre suona, iOS tiene l'app sveglia). La musica si abbassa
/// per la durata della sequenza (audio session con ducking) e poi torna al suo volume.
/// Timbro «legno» (scelta dell'utente del 24/11, campione B): attacco netto, coda breve, passa-basso.
/// Le vibrazioni restano a ogni secondo e si sentono solo con l'app in primo piano.
@MainActor
final class Segnali {
    static let shared = Segnali()

    private let motore = AVAudioEngine()
    private let lettore = AVAudioPlayerNode()
    private let formato = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var collegato = false
    /// Ogni sequenza incrementa il turno: la sessione audio si rilascia solo dopo l'ultima.
    private var turno = 0
    /// «Via» della sequenza in coda: la stessa sequenza non si programma due volte
    /// (la schermata e il pulsante della Live Activity possono chiederla insieme).
    private var viaInCoda: Date?

    private init() {}

    // MARK: Sequenza

    /// Mette in coda i bip agli istanti `bip` e il «via» all'istante `via`. Gli istanti già passati si saltano.
    func sequenza(bip: [Date], via: Date) {
        guard UserDefaults.standard.bool(forKey: Impostazioni.bip) else { return }
        if let viaInCoda, abs(viaInCoda.timeIntervalSince(via)) < 0.05 { return }
        let adesso = Date()
        guard via.timeIntervalSince(adesso) > -0.2 else { return }
        var suoni: [(inizio: TimeInterval, tono: [Float])] = bip.compactMap { istante -> (inizio: TimeInterval, tono: [Float])? in
            let inizio = istante.timeIntervalSince(adesso)
            return inizio > -0.05 ? (max(0, inizio), Self.secondo) : nil
        }
        suoni.append((max(0, via.timeIntervalSince(adesso)), Self.via))
        guard let buffer = buffer(suoni) else { return }
        do {
            let sessione = AVAudioSession.sharedInstance()
            try sessione.setCategory(.playback, mode: .default, options: [.duckOthers])
            try sessione.setActive(true)
            if !collegato {
                motore.attach(lettore)
                motore.connect(lettore, to: motore.mainMixerNode, format: formato)
                collegato = true
            }
            if !motore.isRunning { try motore.start() }
            lettore.stop()
            turno += 1
            let questo = turno
            viaInCoda = via
            lettore.scheduleBuffer(buffer) { [weak self] in
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    self?.rilascia(dopo: questo)
                }
            }
            lettore.play()
        } catch {
            // Senza audio resta la vibrazione: il 3-2-1 si vede comunque sullo schermo.
        }
    }

    /// Ferma la sequenza con questo «via» (3-2-1 annullato, recupero allungato con +15 s, set iniziato prima).
    func ferma(via: Date) {
        guard let viaInCoda, abs(viaInCoda.timeIntervalSince(via)) < 0.05 else { return }
        turno += 1
        rilascia(dopo: turno)
    }

    /// Ferma il motore e restituisce l'audio alla musica, se nel frattempo non è partita un'altra sequenza.
    private func rilascia(dopo questo: Int) {
        guard questo == turno else { return }
        viaInCoda = nil
        lettore.stop()
        motore.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func buffer(_ suoni: [(inizio: TimeInterval, tono: [Float])]) -> AVAudioPCMBuffer? {
        let frequenza = formato.sampleRate
        let fine = suoni.map { Int($0.inizio * frequenza) + $0.tono.count }.max() ?? 0
        guard fine > 0, let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: AVAudioFrameCount(fine)),
              let canale = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(fine)
        for indice in 0..<fine { canale[indice] = 0 }
        for suono in suoni {
            let partenza = Int(suono.inizio * frequenza)
            for (indice, valore) in suono.tono.enumerated() where partenza + indice < fine {
                canale[partenza + indice] += valore
            }
        }
        return buffer
    }

    // MARK: Timbro

    /// Ogni secondo (3, 2, 1): do5.
    private static let secondo = tono(frequenza: 523.25, durata: 0.16, decadimento: 0.045)
    /// «Via»: sol5, un po' più alto e più lungo.
    private static let via = tono(frequenza: 783.99, durata: 0.40, decadimento: 0.12)

    /// Tono «legno»: fondamentale più la quarta armonica, attacco di 3 ms, decadimento esponenziale,
    /// passa-basso a 1,8 kHz (suono ovattato) e rilascio di 10 ms alla fine (niente «clic»).
    private static func tono(frequenza: Double, durata: Double, decadimento: Double) -> [Float] {
        let campioni = 44_100.0
        let totale = Int(durata * campioni)
        let attacco = 0.003, rilascio = 0.01 * campioni
        let alfa = exp(-2 * Double.pi * 1_800 / campioni)
        var filtrato = 0.0
        var valori = [Float](repeating: 0, count: totale)
        for indice in 0..<totale {
            let tempo = Double(indice) / campioni
            var inviluppo = min(1, tempo / attacco) * exp(-tempo / decadimento)
            inviluppo *= min(1, Double(totale - 1 - indice) / rilascio)
            let onda = sin(2 * Double.pi * frequenza * tempo) + 0.25 * sin(2 * Double.pi * frequenza * 4 * tempo)
            filtrato = (1 - alfa) * (0.38 * inviluppo * onda) + alfa * filtrato
            valori[indice] = Float(filtrato)
        }
        return valori
    }

    // MARK: Vibrazione

    /// Ogni secondo degli ultimi 3.
    func vibraSecondo() { vibra(forte: false) }

    /// «Via».
    func vibraVia() { vibra(forte: true) }

    private func vibra(forte: Bool) {
        guard UserDefaults.standard.bool(forKey: Impostazioni.vibrazione) else { return }
        if forte {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
        }
    }
}

extension Segnali {
    /// Istanti dei bip degli ultimi 3 secondi prima di `fine` (meno se la durata è più corta).
    static func ultimiTre(prima fine: Date, durata: Int) -> [Date] {
        (1...max(1, min(3, durata))).reversed().map { fine.addingTimeInterval(-TimeInterval($0)) }
    }
}
