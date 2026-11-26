import AVFoundation
import UIKit

/// Bip e vibrazione del 3-2-1 (sempre 3 s, `Countdown`), della fine del recupero alla rovescia e dei set a tempo.
///
/// **Audio sempre acceso (T1, in prova)**: dall'inizio alla fine della sessione l'app tiene acceso
/// l'audio con un silenzio in loop, in mix con la musica (`.playback` + `.mixWithOthers`, come le app
/// Tabata). Così iOS non sospende mai l'app (`UIBackgroundModes: audio`) e i bip partono anche quando
/// il set si avvia dalla Live Activity o dalla Dynamic Island, a schermo bloccato e in silenzioso.
/// Solo durante una sequenza di bip la sessione passa a `.duckOthers` (la musica si abbassa) e poi torna
/// al mix. Si spegne tutto con la fine della sessione (Salva, Elimina, chiusura automatica).
/// Per tornare a prima (audio solo durante i bip) basta mettere `audioSempreAcceso` a `false`.
///
/// I bip di una sequenza (3, 2, 1 e il «via», più alto) sono un solo suono preparato all'inizio e messo
/// in coda tutto insieme. Timbro «legno» (scelta dell'utente del 24/11, campione B): attacco netto, coda
/// breve, passa-basso. Le vibrazioni restano a ogni secondo e si sentono solo con l'app in primo piano.
@MainActor
final class Segnali {
    static let shared = Segnali()

    /// Interruttore della prova T1: `false` = audio acceso solo durante i bip (comportamento di prima).
    static let audioSempreAcceso = true

    private let motore = AVAudioEngine()
    private let lettore = AVAudioPlayerNode()
    /// Silenzio in loop che tiene l'app sveglia per tutta la sessione.
    private let silenzio = AVAudioPlayerNode()
    private let formato = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var collegato = false
    /// C'è una sessione viva e l'audio va tenuto acceso.
    private var tenuto = false
    /// La musica è abbassata (sequenza di bip in corso).
    private var abbassata = false
    /// Ogni sequenza incrementa il turno: la sessione audio si rilascia solo dopo l'ultima.
    private var turno = 0
    /// «Via» della sequenza in coda: la stessa sequenza non si programma due volte
    /// (la schermata e il pulsante della Live Activity possono chiederla insieme).
    private var viaInCoda: Date?

    private init() {
        let centro = NotificationCenter.default
        // Telefonata, Siri, sveglia: a interruzione finita l'audio riparte.
        centro.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { avviso in
            let valore = avviso.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard valore == AVAudioSession.InterruptionType.ended.rawValue else { return }
            Task { @MainActor in Segnali.shared.riprendi() }
        }
        // Cuffie collegate o staccate: il motore si ferma e va riavviato.
        centro.addObserver(forName: .AVAudioEngineConfigurationChange, object: motore, queue: .main) { _ in
            Task { @MainActor in Segnali.shared.riprendi() }
        }
        centro.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil,
                           queue: .main) { _ in
            Task { @MainActor in Segnali.shared.riprendi() }
        }
    }

    // MARK: Audio della sessione

    /// Da chiamare a ogni cambio della sessione viva: `true` finché la sessione c'è, `false` quando finisce.
    /// Chiamate ripetute costano poco; se nel frattempo l'audio si è fermato, riparte.
    func tieniAcceso(_ acceso: Bool) {
        guard Self.audioSempreAcceso else { return }
        if acceso {
            tenuto = true
            if !motore.isRunning || !silenzio.isPlaying { riprendi() }
        } else if tenuto {
            tenuto = false
            turno += 1
            viaInCoda = nil
            spegni()
        }
    }

    /// Riaccende l'audio della sessione (dopo un'interruzione o un cambio di uscita), se serve.
    private func riprendi() {
        guard tenuto else { return }
        if !motore.isRunning { silenzio.stop() }
        do {
            try attiva(abbassa: abbassata)
        } catch {
            // Al prossimo cambio della sessione (o al ritorno in primo piano) si riprova.
        }
    }

    /// Imposta la sessione audio, avvia il motore e il silenzio in loop.
    private func attiva(abbassa: Bool) throws {
        let sessione = AVAudioSession.sharedInstance()
        try sessione.setCategory(.playback, mode: .default, options: abbassa ? [.duckOthers] : [.mixWithOthers])
        try sessione.setActive(true)
        collega()
        if !motore.isRunning { try motore.start() }
        if tenuto, !silenzio.isPlaying, let vuoto = bufferSilenzio {
            silenzio.scheduleBuffer(vuoto, at: nil, options: .loops)
            silenzio.play()
        }
    }

    /// Passa dal mix al ducking o al contrario. Per alzare di nuovo la musica iOS vuole che la sessione
    /// si disattivi: si ferma il motore un istante, si disattiva, si riattiva in mix e si riparte.
    private func cambiaVolumeMusica(abbassa: Bool) throws {
        guard abbassa != abbassata || !motore.isRunning else { return }
        abbassata = abbassa
        if abbassa {
            try attiva(abbassa: true)
            return
        }
        silenzio.stop()
        lettore.stop()
        motore.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try attiva(abbassa: false)
    }

    /// Fine della sessione: niente più audio, la musica torna al suo volume.
    private func spegni() {
        abbassata = false
        silenzio.stop()
        lettore.stop()
        motore.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func collega() {
        guard !collegato else { return }
        motore.attach(lettore)
        motore.attach(silenzio)
        motore.connect(lettore, to: motore.mainMixerNode, format: formato)
        motore.connect(silenzio, to: motore.mainMixerNode, format: formato)
        collegato = true
    }

    /// Un secondo di silenzio, ripetuto in loop.
    private lazy var bufferSilenzio: AVAudioPCMBuffer? = {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: 44_100),
              let canale = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = 44_100
        for indice in 0..<44_100 { canale[indice] = 0 }
        return buffer
    }()

    // MARK: Sequenza

    /// Programma i bip agli istanti `bip` e il «via» all'istante `via`, sull'orologio dell'audio: ogni suono
    /// esce dall'altoparlante nell'istante dato (compensando la latenza di uscita), così cade al cambio del
    /// numero e dell'anello del 3-2-1 (stessi istanti, da `Countdown`). Gli istanti già passati si saltano.
    func sequenza(bip: [Date], via: Date) {
        guard UserDefaults.standard.bool(forKey: Impostazioni.bip) else { return }
        if let viaInCoda, abs(viaInCoda.timeIntervalSince(via)) < 0.05 { return }
        guard via.timeIntervalSinceNow > -0.2 else { return }
        do {
            // Prima si prepara l'audio (musica abbassata), poi si prendono i tempi: la preparazione
            // non deve spostare i bip.
            if tenuto {
                try cambiaVolumeMusica(abbassa: true)
            } else {
                let sessione = AVAudioSession.sharedInstance()
                try sessione.setCategory(.playback, mode: .default, options: [.duckOthers])
                try sessione.setActive(true)
                collega()
                if !motore.isRunning { try motore.start() }
            }
            lettore.stop()
            let sessione = AVAudioSession.sharedInstance()
            let latenza = max(0, sessione.outputLatency + sessione.ioBufferDuration)
            let oraHost = mach_absolute_time()
            let adesso = Date()
            // Istante (all'altoparlante) del primo campione del suono: il primo bip, o il primo istante
            // utile se l'audio è arrivato tardi.
            let primoUtile = adesso.addingTimeInterval(latenza + Self.margine)
            let origine = max(bip.min() ?? via, primoUtile)
            var suoni: [(inizio: TimeInterval, tono: [Float])] = bip.compactMap { istante -> (inizio: TimeInterval, tono: [Float])? in
                let inizio = istante.timeIntervalSince(origine)
                return inizio > -0.05 ? (max(0, inizio), Self.secondo) : nil
            }
            suoni.append((max(0, via.timeIntervalSince(origine)), Self.via))
            guard let buffer = buffer(suoni) else {
                if tenuto { try? cambiaVolumeMusica(abbassa: false) } else { spegni() }
                return
            }
            let anticipo = max(0, origine.timeIntervalSince(adesso) - latenza)
            let quando = AVAudioTime(hostTime: oraHost + AVAudioTime.hostTime(forSeconds: anticipo))
            turno += 1
            let questo = turno
            viaInCoda = via
            lettore.scheduleBuffer(buffer) { [weak self] in
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    self?.rilascia(dopo: questo)
                }
            }
            lettore.play(at: quando)
        } catch {
            // Senza audio resta la vibrazione: il 3-2-1 si vede comunque sullo schermo.
        }
    }

    /// Margine per programmare il primo suono nel futuro anche quando l'audio arriva tardi.
    private static let margine: TimeInterval = 0.02

    /// Ferma la sequenza con questo «via» (3-2-1 annullato, recupero allungato con +15 s, set iniziato prima).
    func ferma(via: Date) {
        guard let viaInCoda, abs(viaInCoda.timeIntervalSince(via)) < 0.05 else { return }
        turno += 1
        rilascia(dopo: turno)
    }

    /// Fine della sequenza, se nel frattempo non ne è partita un'altra: con la sessione viva l'audio resta
    /// acceso in mix e la musica torna su; senza, si ferma il motore e l'audio torna alla musica.
    private func rilascia(dopo questo: Int) {
        guard questo == turno else { return }
        viaInCoda = nil
        lettore.stop()
        if tenuto {
            try? cambiaVolumeMusica(abbassa: false)
        } else {
            spegni()
        }
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
