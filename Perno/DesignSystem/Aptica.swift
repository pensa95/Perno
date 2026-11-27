import SwiftUI
import UIKit

/// Grammatica aptica dell'app (C4): un solo punto con i tipi di vibrazione, così gesti simili sentono
/// sempre uguali. Rispetta l'interruttore «Vibrazione» delle Impostazioni (come il 3-2-1 in `Segnali`).
///
/// | Gesto | Tipo |
/// |---|---|
/// | «Set fatto» | `.setFatto`: successo, deciso |
/// | − e + di ripetizioni, peso e durata | `.meno` (morbido) e `.piu` (leggero): un tick a ogni tocco |
/// | Faccine, selettori a segmenti | `.selezione` |
/// | Scorrimento di «Rimuovi» oltre la metà | `.soglia`: colpo medio |
/// | Record battuto (C9) | `.record`: successo |
///
/// `.piu` e `.meno` fanno il lavoro di `SensoryFeedback.increase` / `.decrease` di SwiftUI, che hanno bisogno
/// di un valore da osservare; qui i tocchi sono azioni di pulsanti, quindi si usano i generatori di UIKit.
enum Aptica {
    case setFatto
    case piu
    case meno
    case selezione
    case soglia
    case record

    func dai() {
        guard UserDefaults.standard.bool(forKey: Impostazioni.vibrazione) else { return }
        switch self {
        case .setFatto, .record:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .piu:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
        case .meno:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.8)
        case .selezione:
            UISelectionFeedbackGenerator().selectionChanged()
        case .soglia:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    /// Tick di un pulsante − o +.
    static func tick(piu aumenta: Bool) {
        (aumenta ? Aptica.piu : Aptica.meno).dai()
    }
}
