import Foundation

// MARK: - Plan hybride (Premium)

/// Huit semaines pour préparer une course hybride (8 × 1 km + 8 ateliers) :
/// muscu, fractionné, ateliers et enchaînements, planifiés **ensemble**.
///
/// C'est ce qu'aucune app de course ni de muscu ne sait faire : l'ordre de la
/// semaine protège les jambes. Lundi haut du corps (les jambes récupèrent de
/// l'enchaînement du dimanche), mercredi fractionné, vendredi jambes et
/// ateliers, dimanche enchaînement : jamais de séance lourde du bas du corps
/// la veille d'une séance de course.
///
/// Le fractionné reprend la progression du plan 10 km, qui dure lui aussi
/// huit semaines : même logique de phases, mêmes allures tirées de la VMA.
enum HybridPlan {

    static let weekCount = 8

    struct Session: Identifiable {
        enum Kind: String {
            case upperStrength, runQuality, legsAndStations, hybrid
        }

        let id = UUID()
        let kind: Kind
        /// Jour conseillé : 1 = lundi … 7 = dimanche.
        let day: Int
        let title: String
        let detail: String
        let minutes: Int
        /// Fractionné guidé, aux allures de la VMA (séance du mercredi).
        let run: TrainingPlans.Session?
        /// La séance se chronomètre dans le simulateur de course hybride.
        let opensRaceSimulator: Bool

        /// Sollicite fortement les jambes (pour la règle des 48 h).
        var loadsLegs: Bool { kind != .upperStrength }
    }

    struct Week: Identifiable {
        let id = UUID()
        let number: Int
        let phase: TrainingPlans.Phase
        let sessions: [Session]
    }

    static func weeks() -> [Week] {
        let runWeeks = TrainingPlans.weeks(for: .tenK)
        return (1...weekCount).map { number in
            let phase = TrainingPlans.phase(week: number, of: weekCount)
            let quality = runWeeks.indices.contains(number - 1)
                ? runWeeks[number - 1].sessions.first { $0.kind == .quality } : nil
            return Week(number: number, phase: phase, sessions: [
                upperStrength(phase),
                runQuality(quality),
                legsAndStations(phase),
                hybrid(week: number),
            ])
        }
    }

    // MARK: Séances

    private static func upperStrength(_ phase: TrainingPlans.Phase) -> Session {
        let (detail, minutes): (String, Int) = switch phase {
        case .base:
            (String(localized: "hybridplan.upper.base"), 45)
        case .development:
            (String(localized: "hybridplan.upper.development"), 50)
        case .specific:
            (String(localized: "hybridplan.upper.specific"), 50)
        case .taper:
            (String(localized: "hybridplan.upper.taper"), 30)
        }
        return Session(kind: .upperStrength, day: 1,
                       title: String(localized: "hybridplan.upper.title"),
                       detail: detail, minutes: minutes, run: nil, opensRaceSimulator: false)
    }

    private static func runQuality(_ quality: TrainingPlans.Session?) -> Session {
        Session(kind: .runQuality, day: 3,
                title: String(localized: "hybridplan.run.title"),
                detail: String(localized: "hybridplan.run.detail"),
                minutes: quality?.minutes ?? 40, run: quality, opensRaceSimulator: false)
    }

    private static func legsAndStations(_ phase: TrainingPlans.Phase) -> Session {
        let (detail, minutes): (String, Int) = switch phase {
        case .base:
            (String(localized: "hybridplan.legs.base"), 55)
        case .development:
            (String(localized: "hybridplan.legs.development"), 60)
        case .specific:
            (String(localized: "hybridplan.legs.specific"), 60)
        case .taper:
            (String(localized: "hybridplan.legs.taper"), 35)
        }
        return Session(kind: .legsAndStations, day: 5,
                       title: String(localized: "hybridplan.legs.title"),
                       detail: detail, minutes: minutes, run: nil, opensRaceSimulator: false)
    }

    /// L'enchaînement du dimanche monte en puissance : quelques tours d'abord,
    /// puis la demi-course, la course complète à allure contrôlée, et une
    /// demi-course chronométrée juste avant l'affûtage.
    private static func hybrid(week: Int) -> Session {
        // Chaque clé passée directement à `String(localized:)` : via une
        // variable intermédiaire, Xcode n'extrait pas la clé dans le catalogue.
        let (detail, minutes, simulator): (String, Int, Bool) = switch week {
        case 1, 2: (String(localized: "hybridplan.hybrid.rounds3"), 35, false)
        case 3, 4: (String(localized: "hybridplan.hybrid.half"), 45, true)
        case 5:    (String(localized: "hybridplan.hybrid.rounds6"), 60, false)
        case 6:    (String(localized: "hybridplan.hybrid.full"), 80, true)
        case 7:    (String(localized: "hybridplan.hybrid.halfTimed"), 45, true)
        default:   (String(localized: "hybridplan.hybrid.taper"), 30, false)
        }
        return Session(kind: .hybrid, day: 7,
                       title: String(localized: "hybridplan.hybrid.title"),
                       detail: detail, minutes: minutes,
                       run: nil, opensRaceSimulator: simulator)
    }
}
