import AudioToolbox
import Foundation
import UIKit

// MARK: - Sons et retours haptiques

/// Regroupe les retours sensoriels de l'app pour qu'ils restent cohérents et
/// qu'ils respectent la préférence « Sons » du profil.
///
/// Les vibrations ne sont **pas** coupées par cette préférence : ce sont deux
/// modalités différentes, et l'utilisateur qui coupe le son veut généralement
/// garder le retour haptique (typiquement en salle, écouteurs branchés).
enum Feedback {

    /// Identifiants de sons système iOS.
    ///
    /// `restFinished` (1007) était déjà utilisé dans l'app : celui-là est éprouvé.
    /// Les autres sont à écouter sur un appareil réel et se changent ici, en un
    /// seul endroit, si le rendu ne convient pas.
    enum Sound: SystemSoundID {
        /// Fin du temps de repos : la série suivante peut commencer.
        case restFinished = 1007
        /// Série validée. Discret : on l'entend une dizaine de fois par séance.
        case setLogged = 1104
        /// Record personnel battu, pendant la séance.
        case record = 1103
    }

    /// Sons activés par défaut : on lit `object(forKey:)` pour distinguer
    /// « jamais réglé » de « réglé à faux ».
    static var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true
    }

    static func play(_ sound: Sound) {
        guard soundsEnabled else { return }
        AudioServicesPlaySystemSound(sound.rawValue)
    }

    // MARK: Événements

    static func restFinished() {
        play(.restFinished)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func setLogged() {
        play(.setLogged)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Record personnel battu **pendant** la séance : accompagne le flash
    /// « Record ! ». C'est le seul son de célébration conservé, parce qu'il
    /// signale quelque chose que l'utilisateur ne regardait pas forcément.
    static func record() {
        play(.record)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Fin de séance de musculation : **vibration seule, pas de son**.
    ///
    /// Choix délibéré : l'écran de célébration est déjà très expressif
    /// (confettis, stats, animations), un son par-dessus faisait de trop.
    static func workoutFinished() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Fin de course : même raisonnement que la fin de séance.
    static func runFinished() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Repère chronométré d'une séance : départ de test, dernière minute,
    /// transition de fractionné.
    ///
    /// Ceux-là **ignorent volontairement** la préférence « Sons » : ils ne
    /// décorent pas l'app, ils *sont* le mécanisme de la séance. Les couper
    /// rendrait le test de VMA et le fractionné inutilisables sans regarder
    /// l'écran en permanence.
    static func cue(_ count: Int = 1) {
        for i in 0..<max(1, count) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.28) {
                AudioServicesPlaySystemSound(Sound.restFinished.rawValue)
            }
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
