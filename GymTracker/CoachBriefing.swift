import Foundation

// MARK: - Bilan croisé

/// Croise musculation, course et nutrition sur une fenêtre glissante.
///
/// C'est le socle du coach : **Swift calcule tous les chiffres**. Un modèle de
/// langage embarqué ne fera plus tard que les mettre en phrase. Un modèle de
/// quelques milliards de paramètres se trompe sur l'arithmétique, et un chiffre
/// faux dans une app de suivi détruit la confiance dans tous les autres.
///
/// C'est aussi la seule analyse que les concurrents ne peuvent pas produire :
/// ils n'ont qu'un des trois domaines.
struct CoachBriefing {

    /// 14 jours : assez long pour lisser une semaine creuse, assez court pour
    /// que la tendance parle encore du moment présent.
    static let windowDays = 14

    struct Trend {
        let current: Double
        let previous: Double

        /// Variation en pourcentage, ou nil si la période précédente est vide —
        /// « +∞ % » n'apprend rien à personne.
        var changePercent: Double? {
            guard previous > 0.01 else { return nil }
            return (current - previous) / previous * 100
        }

        /// On ne commente qu'au-delà de 15 % : en dessous, c'est du bruit de
        /// calendrier, pas une tendance.
        var isNotable: Bool {
            guard let change = changePercent else { return false }
            return abs(change) >= 15
        }
    }

    let volumeTonnes: Trend
    let kilometres: Trend

    /// Apport quotidien moyen. nil si le journal alimentaire est trop incomplet
    /// pour que la moyenne veuille dire quelque chose.
    let dailyKcal: Double?
    let maintenanceKcal: Double?

    /// Exercice le plus travaillé qui ne progresse plus, et depuis combien de
    /// semaines son meilleur 1RM estimé n'a pas été battu.
    let stalledExercise: String?
    let stalledWeeks: Int

    // MARK: Calcul

    static func make(sets: [SetRecord],
                     runs: [RunSession],
                     food: [FoodEntry],
                     maintenanceKcal: Double?,
                     now: Date = .now) -> CoachBriefing {

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -windowDays * 2, to: now) ?? now

        func volume(_ from: Date, _ to: Date) -> Double {
            sets.filter { $0.date >= from && $0.date < to }
                .reduce(0) { $0 + Double($1.reps) * $1.weight } / 1000
        }

        func distance(_ from: Date, _ to: Date) -> Double {
            runs.filter { $0.date >= from && $0.date < to }
                .reduce(0) { $0 + $1.distanceKm }
        }

        let plateau = stall(in: sets, now: now)

        return CoachBriefing(
            volumeTonnes: Trend(current: volume(start, now),
                                previous: volume(previousStart, start)),
            kilometres: Trend(current: distance(start, now),
                              previous: distance(previousStart, start)),
            dailyKcal: averageDailyKcal(food: food, from: start, to: now),
            maintenanceKcal: maintenanceKcal,
            stalledExercise: plateau?.exercise,
            stalledWeeks: plateau?.weeks ?? 0
        )
    }

    /// Moyenne calculée sur les **jours réellement renseignés**, pas sur la
    /// fenêtre entière.
    ///
    /// Garde-fou important : quelqu'un qui note 3 jours sur 14 verrait sinon
    /// apparaître un déficit calorique imaginaire, les jours non saisis comptant
    /// pour zéro. En dessous de 7 jours notés, on préfère ne rien dire.
    private static func averageDailyKcal(food: [FoodEntry], from: Date, to: Date) -> Double? {
        let calendar = Calendar.current
        let window = food.filter { $0.date >= from && $0.date < to }
        guard !window.isEmpty else { return nil }

        let byDay = Dictionary(grouping: window) { calendar.startOfDay(for: $0.date) }
        guard byDay.count >= 7 else { return nil }

        let total = window.reduce(0.0) { $0 + $1.grams / 100 * $1.kcalPer100 }
        return total / Double(byDay.count)
    }

    /// Détecte un plateau sur l'exercice le plus travaillé.
    ///
    /// Méthode : meilleur 1RM estimé par semaine sur 8 semaines ; si le pic date
    /// d'au moins 3 semaines, c'est un plateau. Un minimum de séries est exigé
    /// pour ne pas qualifier de « plateau » un exercice fait deux fois.
    private static func stall(in sets: [SetRecord], now: Date) -> (exercise: String, weeks: Int)? {
        let calendar = Calendar.current
        guard let horizon = calendar.date(byAdding: .day, value: -56, to: now) else { return nil }
        let recent = sets.filter { $0.date >= horizon && $0.weight > 0 }
        guard recent.count >= 6 else { return nil }

        let counts = Dictionary(grouping: recent, by: \.exerciseName).mapValues(\.count)
        guard let best = counts.max(by: { $0.value < $1.value }), best.value >= 6 else {
            return nil
        }
        let exercise = best.key

        var bestByWeek: [Int: Double] = [:]
        for record in recent where record.exerciseName == exercise {
            let days = calendar.dateComponents([.day], from: record.date, to: now).day ?? 0
            let week = days / 7
            let estimate = StrengthMath.epley1RM(weight: record.weight, reps: record.reps)
            bestByWeek[week] = max(bestByWeek[week] ?? 0, estimate)
        }
        guard bestByWeek.count >= 4,
              let peakWeek = bestByWeek.max(by: { $0.value < $1.value })?.key,
              peakWeek >= 3
        else { return nil }

        return (exercise, peakWeek)
    }
}
