import Foundation
import SwiftData

// MARK: - Objectif nutritionnel (Premium)

enum NutritionGoal: String, CaseIterable, Identifiable {
    case cut = "Sèche"
    case maintain = "Maintien"
    case bulk = "Prise de masse"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cut: "arrow.down.right.circle.fill"
        case .maintain: "equal.circle.fill"
        case .bulk: "arrow.up.right.circle.fill"
        }
    }

    /// Multiplicateur appliqué à la dépense totale (TDEE)
    var calorieFactor: Double {
        switch self {
        case .cut: 0.83        // déficit ~17 %
        case .maintain: 1.0
        case .bulk: 1.12       // surplus ~12 %
        }
    }

    /// Protéines recommandées (g par kg de poids de corps)
    var proteinPerKg: Double {
        switch self {
        case .cut: 2.2         // préserve le muscle en déficit
        case .maintain: 1.6
        case .bulk: 1.8
        }
    }

    var blurb: String {
        switch self {
        case .cut: "Déficit d'environ 17 % pour perdre du gras en préservant le muscle."
        case .maintain: "L'équilibre : tu manges ce que tu dépenses."
        case .bulk: "Surplus d'environ 12 % pour construire du muscle."
        }
    }
}

// MARK: - Plan calculé

struct NutritionPlan {
    let bmr: Double            // métabolisme de base
    let tdee: Double           // dépense totale estimée
    let targetKcal: Double     // objectif du jour selon le régime
    let proteinG: Double
    let fatG: Double
    let carbsG: Double
}

// MARK: - Calculs (Mifflin-St Jeor + activité réellement mesurée par l'app)

enum NutritionPlanner {

    /// Moyenne d'activités par semaine sur les 4 dernières semaines (séances + courses)
    static func weeklyActivities(context: ModelContext) -> Double {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: .now) else { return 0 }
        let sessions = (try? context.fetchCount(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.date >= cutoff }))) ?? 0
        let runs = (try? context.fetchCount(FetchDescriptor<RunSession>(
            predicate: #Predicate { $0.date >= cutoff }))) ?? 0
        return Double(sessions + runs) / 4.0
    }

    static func plan(weightKg: Double, heightCm: Int, age: Int, sex: UserSex,
                     weeklyActivities: Double, goal: NutritionGoal) -> NutritionPlan {
        // Mifflin-St Jeor
        let sexOffset: Double = switch sex {
        case .male: 5
        case .female: -161
        case .unspecified: -78    // moyenne des deux
        }
        let bmr = 10 * weightKg + 6.25 * Double(heightCm) - 5 * Double(age) + sexOffset

        // Facteur d'activité calibré sur les activités réellement enregistrées :
        // 1.2 (sédentaire) + ~0.055 par activité hebdomadaire, plafonné à 1.75
        let factor = min(1.2 + 0.055 * weeklyActivities, 1.75)
        let tdee = bmr * factor

        // Jamais sous le métabolisme de base, même en sèche
        let target = max(tdee * goal.calorieFactor, bmr)

        let protein = goal.proteinPerKg * weightKg
        let fat = 1.0 * weightKg
        let carbs = max((target - protein * 4 - fat * 9) / 4, 0)

        return NutritionPlan(bmr: bmr, tdee: tdee, targetKcal: target,
                             proteinG: protein, fatG: fat, carbsG: carbs)
    }
}

// MARK: - Calories brûlées (estimation MET)

enum CalorieEstimator {
    /// Musculation : MET ≈ 5.0 (effort modéré à soutenu avec repos)
    static func workoutKcal(durationSeconds: Int, weightKg: Double) -> Int {
        guard weightKg > 0, durationSeconds > 0 else { return 0 }
        return Int(5.0 * weightKg * Double(durationSeconds) / 3600)
    }

    /// Course : ≈ 1 kcal par kg et par km (bonne approximation indépendante de l'allure)
    static func runKcal(distanceKm: Double, weightKg: Double) -> Int {
        guard weightKg > 0, distanceKm > 0 else { return 0 }
        return Int(weightKg * distanceKm)
    }
}

// MARK: - Catalogue d'aliments (table CIQUAL 2020, ANSES, licence ouverte Etalab)

struct CiqualFood: Codable, Identifiable, Hashable {
    let n: String              // nom
    let k: Double              // kcal / 100 g
    let p: Double              // protéines g / 100 g
    let c: Double              // glucides g / 100 g
    let f: Double              // lipides g / 100 g

    var id: String { n }
    var name: String { n }
}

enum FoodCatalog {
    static let all: [CiqualFood] = {
        guard let url = Bundle.main.url(forResource: "foods_ciqual", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CiqualFood].self, from: data)
        else {
            assertionFailure("foods_ciqual.json introuvable dans le bundle")
            return []
        }
        return items
    }()

    /// Recherche insensible à la casse et aux accents
    static func search(_ query: String) -> [CiqualFood] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(all.prefix(60)) }
        return all.filter { $0.n.localizedStandardContains(trimmed) }
    }
}

// MARK: - Repas

enum MealKind: String, CaseIterable, Identifiable {
    case breakfast = "Petit-déjeuner"
    case lunch = "Déjeuner"
    case dinner = "Dîner"
    case snack = "Collation"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: "cup.and.saucer.fill"
        case .lunch: "fork.knife"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }
}
