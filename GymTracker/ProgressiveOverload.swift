import Foundation

// MARK: - Surcharge progressive

/// Objectif de la prochaine séance pour un exercice, par **double progression**.
///
/// La méthode la plus répandue et la plus simple à suivre : on reste sur une
/// charge tant que toutes les séries n'atteignent pas le haut de la fourchette
/// de répétitions ; quand c'est le cas, on ajoute un cran de charge et on repart
/// du bas de la fourchette.
///
/// C'est ce qui transforme un carnet d'entraînement en coach : l'app ne se
/// contente plus de rappeler ce qu'on a fait, elle dit ce qu'on vise.
enum ProgressiveOverload {

    // MARK: Fourchette de répétitions

    struct RepRange: Equatable {
        let min: Int
        let max: Int
        /// Exercice au temps (gainage : « 45-60 s ») — la valeur est en secondes.
        let isTimed: Bool
    }

    /// Lit une fourchette saisie librement : « 6-8 », « 8–12 », « 10 »,
    /// « 8 à 12 », « 45-60 s ». nil si rien d'exploitable.
    static func parse(_ text: String) -> RepRange? {
        let lowered = text.lowercased()
        let isTimed = lowered.contains("s") && !lowered.contains("rep")
        let numbers = lowered
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
            .filter { $0 > 0 }
        guard let first = numbers.first else { return nil }
        let second = numbers.count > 1 ? numbers[1] : first
        return RepRange(min: Swift.min(first, second), max: Swift.max(first, second),
                        isTimed: isTimed)
    }

    // MARK: Objectif

    struct PastSet: Equatable {
        let reps: Int
        let weight: Double
    }

    enum Kind: Equatable {
        /// Toutes les séries au plafond : on ajoute de la charge.
        case increaseWeight
        /// Même charge, une répétition (ou 5 s) de plus.
        case addRep
        /// En dessous de la fourchette la dernière fois : on consolide.
        case consolidate
        /// Première séance après une pause : charge réduite (voir `Comeback`).
        case comeback
        /// Semaine allégée : charge réduite, moitié des séries (voir `Deload`).
        case deload
    }

    struct Target: Equatable {
        let reps: Int
        let weight: Double
        let kind: Kind
        /// Charge de référence de la dernière séance, pour l'explication.
        let previousWeight: Double
        let previousReps: Int
    }

    /// Objectif pour la prochaine séance, à partir des séries de la dernière.
    ///
    /// - Parameters:
    ///   - lastSession: séries de la dernière séance où l'exercice a été fait.
    ///   - range: fourchette visée (nil si illisible).
    ///   - increment: cran de charge (voir `increment(equipment:weight:)`).
    static func target(lastSession: [PastSet], range: RepRange?, increment: Double) -> Target? {
        guard let topWeight = lastSession.map(\.weight).max() else { return nil }
        // Séries de travail : celles à la charge la plus lourde. Les séries
        // d'échauffement, plus légères, ne disent rien de la progression.
        let working = lastSession.filter { $0.weight == topWeight }
        guard let weakest = working.map(\.reps).min(),
              let best = working.map(\.reps).max() else { return nil }

        func make(_ reps: Int, _ weight: Double, _ kind: Kind) -> Target {
            Target(reps: reps, weight: weight, kind: kind,
                   previousWeight: topWeight, previousReps: best)
        }

        // Au temps : 5 secondes de plus, sans fin — le gainage n'a pas de « charge ».
        if range?.isTimed == true {
            return make(best + 5, topWeight, .addRep)
        }
        // Poids du corps : on progresse en répétitions.
        if topWeight == 0 || increment == 0 {
            return make(best + 1, topWeight, .addRep)
        }
        guard let range else {
            return make(best + 1, topWeight, .addRep)
        }
        if weakest >= range.max {
            return make(range.min, roundToPlate(topWeight + increment), .increaseWeight)
        }
        if best < range.min {
            return make(range.min, topWeight, .consolidate)
        }
        return make(Swift.min(range.max, weakest + 1), topWeight, .addRep)
    }

    /// Objectif allégé : reprise après une pause ou semaine allégée. La charge
    /// de la dernière séance, réduite et arrondie vers le bas au cran du
    /// matériel ; au poids du corps ou au temps, moins de répétitions.
    static func lighter(lastSession: [PastSet], range: RepRange?, increment: Double,
                        factor: Double, kind: Kind) -> Target? {
        guard let topWeight = lastSession.map(\.weight).max() else { return nil }
        let best = lastSession.filter { $0.weight == topWeight }.map(\.reps).max() ?? 0
        if range?.isTimed == true || topWeight == 0 || increment == 0 {
            let reps = Swift.max(1, Int((Double(best) * factor).rounded(.down)))
            return Target(reps: reps, weight: topWeight, kind: kind,
                          previousWeight: topWeight, previousReps: best)
        }
        let reduced = Swift.max(increment, (topWeight * factor / increment).rounded(.down) * increment)
        return Target(reps: range?.min ?? best, weight: roundToPlate(reduced), kind: kind,
                      previousWeight: topWeight, previousReps: best)
    }

    /// Cran de charge selon le matériel : 2 kg pour les haltères (paires
    /// courantes en salle), 2,5 kg pour une barre ou une machine, 1 kg sous 10 kg.
    static func increment(equipment: String?, weight: Double) -> Double {
        if equipment == "body weight" { return 0 }
        if weight < 10 { return 1 }
        switch equipment {
        case "dumbbell", "kettlebell": return 2
        default: return 2.5
        }
    }

    /// Arrondi au quart de kilo : évite les « 82,4999 kg » d'une addition flottante.
    static func roundToPlate(_ weight: Double) -> Double {
        (weight * 4).rounded() / 4
    }
}
