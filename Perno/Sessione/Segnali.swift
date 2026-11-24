import AVFoundation
import UIKit

/// Bip e vibrazione del 3-2-1 («Prima di ogni set» nelle Impostazioni).
/// Il bip si sente sopra la musica, che si abbassa un attimo (audio session con ducking) e poi
/// torna al suo volume. Il suono è un tono generato al momento: nessun file audio nell'app.
/// Con lo schermo bloccato il 3-2-1 partito dalla Live Activity lo porta a termine l'azione del pulsante
/// (`AttivitaLive`): se i bip si sentono anche lì è da verificare sul telefono.
@MainActor
final class Segnali {
    static let shared = Segnali()

    private let motore = AVAudioEngine()
    private let lettore = AVAudioPlayerNode()
    private let formato = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var collegato = false
    /// Ogni suono incrementa il turno: la sessione audio si rilascia solo dopo l'ultimo.
    private var turno = 0

    private init() {}

    /// Ogni secondo del 3-2-1 (3, 2, 1).
    func secondo() {
        suona(frequenza: 880, durata: 0.12)
        vibra(forte: false)
    }

    /// Fine del 3-2-1: parte il set.
    func via() {
        suona(frequenza: 1_320, durata: 0.35)
        vibra(forte: true)
    }

    // MARK: Bip

    private func suona(frequenza: Double, durata: Double) {
        guard UserDefaults.standard.bool(forKey: Impostazioni.bip), let tono = tono(frequenza, durata) else { return }
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
            turno += 1
            let questo = turno
            lettore.scheduleBuffer(tono) { [weak self] in
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    self?.rilascia(dopo: questo)
                }
            }
            lettore.play()
        } catch {
            // Senza audio resta la vibrazione: il 3-2-1 si vede comunque sullo schermo.
        }
    }

    /// Ferma il motore e restituisce l'audio alla musica, se nel frattempo non è partito un altro bip.
    private func rilascia(dopo questo: Int) {
        guard questo == turno else { return }
        lettore.stop()
        motore.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Tono sinusoidale con attacco e rilascio brevi (niente «clic»).
    private func tono(_ frequenza: Double, _ durata: Double) -> AVAudioPCMBuffer? {
        let frequenzaCampioni = formato.sampleRate
        let campioni = AVAudioFrameCount(durata * frequenzaCampioni)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: campioni),
              let canale = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = campioni
        let rampa = max(1, Int(0.01 * frequenzaCampioni))
        let totale = Int(campioni)
        for indice in 0..<totale {
            let inviluppo = Float(min(1, Double(min(indice, totale - 1 - indice)) / Double(rampa)))
            canale[indice] = 0.6 * inviluppo * Float(sin(2 * Double.pi * frequenza * Double(indice) / frequenzaCampioni))
        }
        return buffer
    }

    // MARK: Vibrazione

    private func vibra(forte: Bool) {
        guard UserDefaults.standard.bool(forKey: Impostazioni.vibrazione) else { return }
        if forte {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
        }
    }
}
