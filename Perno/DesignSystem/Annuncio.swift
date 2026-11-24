import SwiftUI
import UIKit

/// Annunci di VoiceOver (cambi di fase della sessione, «Recupero finito»): solo con VoiceOver attivo.
enum Annuncio {
    @MainActor
    static func voiceOver(_ testo: String) {
        guard UIAccessibility.isVoiceOverRunning, !testo.isEmpty else { return }
        AccessibilityNotification.Announcement(testo).post()
    }
}
