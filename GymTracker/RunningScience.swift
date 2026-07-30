import Foundation

// MARK: - VMA et allures d'entraînement

/// Vitesse Maximale Aérobie et allures qui en découlent.
///
/// Test retenu : le **demi-Cooper** — la plus grande distance possible en
/// 6 minutes. La VMA est alors simplement la vitesse moyenne sur ces 6 minutes,
/// ce qui la rend facile à expliquer : 1 500 m parcourus = 15 km/h.
///
/// Choix assumé : ce test se fait seul, sur route comme sur piste, sans plots ni
/// bande sonore de paliers. Un VAMEVAL serait plus précis mais suppose une piste
/// balisée — donc ne serait jamais utilisé.
enum RunningScience {

    /// Durée du test, en secondes.
    static let testDuration = 6 * 60

    /// Bornes de plausibilité (km/h). En dehors, le test s'est mal passé — GPS
    /// perdu, abandon, marche — et mieux vaut ne rien enregistrer qu'une valeur
    /// fausse dont découleraient toutes les allures.
    static let plausibleRange: ClosedRange<Double> = 8...25

    /// VMA en km/h depuis la distance couverte pendant le test.
    ///
    /// Arrondie au demi km/h : c'est la précision réelle de ce genre de test,
    /// afficher 15,3 km/h donnerait une fausse impression d'exactitude.
    static func vma(fromTestDistanceMeters meters: Double) -> Double {
        ((meters / 100) * 2).rounded() / 2
    }

    /// Allure en secondes par kilomètre pour une vitesse en km/h.
    static func paceSecPerKm(speedKmh: Double) -> Int {
        guard speedKmh > 0 else { return 0 }
        return Int((3600 / speedKmh).rounded())
    }

    // MARK: Zones d'entraînement

    enum Zone: String, CaseIterable, Identifiable {
        case easy, marathon, halfMarathon, tenK, vmaLong, vmaShort

        var id: String { rawValue }

        /// Fourchette exprimée en pourcentage de la VMA.
        var percentRange: ClosedRange<Double> {
            switch self {
            case .easy:         0.65...0.75
            case .marathon:     0.75...0.80
            case .halfMarathon: 0.80...0.85
            case .tenK:         0.85...0.90
            case .vmaLong:      0.95...1.00
            case .vmaShort:     1.00...1.10
            }
        }

        var label: String {
            switch self {
            case .easy:         String(localized: "run.zone.easy")
            case .marathon:     String(localized: "run.zone.marathon")
            case .halfMarathon: String(localized: "run.zone.half")
            case .tenK:         String(localized: "run.zone.tenK")
            case .vmaLong:      String(localized: "run.zone.vmaLong")
            case .vmaShort:     String(localized: "run.zone.vmaShort")
            }
        }

        var detail: String {
            switch self {
            case .easy:         String(localized: "run.zone.easy.detail")
            case .marathon:     String(localized: "run.zone.marathon.detail")
            case .halfMarathon: String(localized: "run.zone.half.detail")
            case .tenK:         String(localized: "run.zone.tenK.detail")
            case .vmaLong:      String(localized: "run.zone.vmaLong.detail")
            case .vmaShort:     String(localized: "run.zone.vmaShort.detail")
            }
        }
    }

    /// Fourchette d'allure (secondes par km) d'une zone pour une VMA donnée.
    ///
    /// Attention au piège : plus la **vitesse** est élevée, plus l'**allure** est
    /// basse. La fourchette de pourcentages s'inverse donc quand on la convertit
    /// en allure — d'où le min/max explicite plutôt qu'un simple mappage.
    static func paceRange(zone: Zone, vma: Double) -> (fast: Int, slow: Int) {
        let a = paceSecPerKm(speedKmh: vma * zone.percentRange.lowerBound)
        let b = paceSecPerKm(speedKmh: vma * zone.percentRange.upperBound)
        return (fast: min(a, b), slow: max(a, b))
    }
}

// MARK: - VMA enregistrée

/// Stockée dans les préférences plutôt que dans SwiftData : une seule valeur
/// scalaire, donc aucune migration de schéma pour les utilisateurs déjà installés.
enum VMAStore {
    private static let valueKey = "vmaKmh"
    private static let dateKey = "vmaTestDate"

    /// nil tant qu'aucun test crédible n'a été passé.
    static var value: Double? {
        let stored = UserDefaults.standard.double(forKey: valueKey)
        return RunningScience.plausibleRange.contains(stored) ? stored : nil
    }

    static var testDate: Date? {
        UserDefaults.standard.object(forKey: dateKey) as? Date
    }

    static func save(_ vma: Double, on date: Date = .now) {
        UserDefaults.standard.set(vma, forKey: valueKey)
        UserDefaults.standard.set(date, forKey: dateKey)
    }
}
