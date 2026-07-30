import Foundation

// MARK: - Points d'expérience et niveaux

/// Points calculés **à la volée** depuis l'historique, jamais stockés.
///
/// Choix délibéré, pour trois raisons :
///
/// - **Aucune migration de schéma** : les utilisateurs déjà installés n'ont rien
///   à mettre à jour.
/// - **Aucune dérive** : un compteur persisté se désynchronise dès qu'une séance
///   est supprimée ou modifiée. Ici le total est exact par construction.
/// - **XP rétroactive** : quelqu'un qui met à jour l'app retrouve d'emblée un
///   niveau correspondant à son historique, au lieu de repartir de zéro.
///
/// Les composantes sont conservées séparément (et pas seulement le total) pour
/// que l'écran de détail puisse montrer *d'où* viennent les points, avec les
/// chiffres réels de l'utilisateur.
struct Progression {

    // MARK: Barème
    //
    // Volontairement lisible : l'utilisateur doit pouvoir deviner d'où viennent
    // ses points sans lire de documentation.

    /// Points pour une séance de musculation terminée.
    static let perWorkout = 50
    /// Points par tonne (1 000 kg) de volume soulevé.
    static let perTonneLifted = 10
    /// Points par kilomètre couru.
    static let perKilometre = 10
    /// Points par complément coché.
    static let perSupplementIntake = 2

    // MARK: Composantes mesurées

    let workoutCount: Int
    let tonnesLifted: Double
    let kilometresRun: Double
    let supplementCount: Int

    init(workouts: [WorkoutSession], runs: [RunSession], intakes: [SupplementIntake]) {
        workoutCount = workouts.count
        tonnesLifted = workouts.reduce(0.0) { $0 + $1.totalVolume } / 1000
        kilometresRun = runs.reduce(0.0) { $0 + $1.distanceKm }
        supplementCount = intakes.count
    }

    // MARK: Points par source

    var workoutXP: Int { workoutCount * Self.perWorkout }
    var volumeXP: Int { Int(tonnesLifted * Double(Self.perTonneLifted)) }
    var runXP: Int { Int(kilometresRun * Double(Self.perKilometre)) }
    var supplementXP: Int { supplementCount * Self.perSupplementIntake }

    var totalXP: Int { workoutXP + volumeXP + runXP + supplementXP }

    // MARK: Niveaux

    /// XP cumulée nécessaire pour atteindre un niveau : 0, 100, 300, 600, 1 000…
    ///
    /// Le premier palier tombe après une séance ou deux : monter de niveau vite
    /// donne envie de continuer. L'écart croît ensuite régulièrement.
    static func xpRequired(forLevel level: Int) -> Int {
        max(0, 50 * level * (level - 1))
    }

    var level: Int {
        var level = 1
        while Self.xpRequired(forLevel: level + 1) <= totalXP { level += 1 }
        return level
    }

    /// XP engrangée depuis le début du niveau courant.
    var xpAtCurrentLevel: Int { totalXP - Self.xpRequired(forLevel: level) }

    /// XP nécessaire pour franchir le niveau courant.
    var xpForThisLevel: Int {
        Self.xpRequired(forLevel: level + 1) - Self.xpRequired(forLevel: level)
    }

    /// Avancement vers le niveau suivant, entre 0 et 1.
    var progress: Double {
        guard xpForThisLevel > 0 else { return 1 }
        return min(1, Double(xpAtCurrentLevel) / Double(xpForThisLevel))
    }

    /// Fenêtre de paliers affichée dans l'écran de détail : on garde le niveau
    /// précédent en repère et on montre ce qui vient.
    var nearbyLevels: [Int] {
        let start = max(1, level - 1)
        return Array(start...(start + 5))
    }

    /// Titre du palier, traduit.
    ///
    /// Ce sont des **noms** et non des adjectifs (« Régularité » plutôt que
    /// « Régulier/Régulière ») : ils ne portent donc aucun accord de genre, ni en
    /// français ni en espagnol. Voir `InclusiveText` pour le reste.
    var title: String {
        switch level {
        case 1...2:   String(localized: "progression.tier.start")
        case 3...4:   String(localized: "progression.tier.rhythm")
        case 5...6:   String(localized: "progression.tier.consistency")
        case 7...9:   String(localized: "progression.tier.strength")
        case 10...14: String(localized: "progression.tier.machine")
        default:      String(localized: "progression.tier.legend")
        }
    }
}
