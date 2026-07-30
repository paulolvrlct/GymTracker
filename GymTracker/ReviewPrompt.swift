import Foundation
import StoreKit
// `RequestReviewAction` vient de la surcouche SwiftUI de StoreKit : les deux
// imports sont nécessaires.
import SwiftUI

// MARK: - Demande de note sur l'App Store

/// Décide *quand* proposer de noter l'app.
///
/// Trois règles, pour ne jamais tomber au mauvais moment :
///
/// 1. **Seulement après une séance enregistrée.** Une séance abandonnée ne
///    déclenche rien.
/// 2. **Pas avant la 3ᵉ séance.** On ne demande pas son avis à quelqu'un qui
///    découvre encore l'app.
/// 3. **Une fois par version au maximum**, et jamais pendant la célébration :
///    la demande arrive au retour sur l'écran qui a lancé la séance.
///
/// iOS applique de son côté sa propre limite (3 demandes par an) et peut donc
/// ignorer l'appel : c'est normal, il ne faut pas chercher à le contourner.
enum ReviewPrompt {

    private static let pendingKey = "reviewPromptPending"
    private static let countKey = "reviewPromptWorkoutCount"
    private static let versionKey = "reviewPromptLastVersion"

    /// Nombre de séances terminées avant la première demande.
    private static let minimumWorkouts = 3

    /// À appeler quand une séance vient d'être enregistrée avec succès.
    ///
    /// Le compteur est propre à cette mécanique (il ne relit pas l'historique
    /// SwiftData) : la séance peut être lancée depuis l'accueil ou depuis
    /// l'onglet Séances, et les deux passent par ici.
    static func workoutCompleted() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        defaults.set(true, forKey: pendingKey)
    }

    /// À appeler au retour sur l'écran qui a lancé la séance.
    @MainActor
    static func askIfEarned(_ request: RequestReviewAction) {
        let defaults = UserDefaults.standard

        // On consomme le drapeau quoi qu'il arrive : pas de demande en retard.
        guard defaults.bool(forKey: pendingKey) else { return }
        defaults.set(false, forKey: pendingKey)

        guard defaults.integer(forKey: countKey) >= minimumWorkouts else { return }

        let version = Bundle.main.displayVersion
        guard defaults.string(forKey: versionKey) != version else { return }
        defaults.set(version, forKey: versionKey)

        // Laisse l'écran de séance finir de se refermer avant que la feuille
        // système apparaisse, sinon elle peut être avalée par la transition.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            request()
        }
    }
}
