import Foundation
import SwiftUI

// MARK: - Entrée du catalogue
// Structure textuelle du dataset (noms, muscles, instructions) — licence MIT, exploitable.
// Les médias propriétaires (JPG/GIF Gym visual) ont été retirés du JSON : pas de
// publication App Store possible avec eux. Point d'extension pour des visuels libres
// de droits (API wger, Free Exercise DB) : réintroduire ici une `imageURL` calculée
// depuis la nouvelle source, et remplacer `ExerciseIllustration` aux points d'usage.

struct CatalogExercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let equipment: String
    let target: String
    let secondary: [String]
    let steps: [String]

    /// Nom affiché : traduction curée si elle existe, sinon le nom source du
    /// dataset — cf. `ExerciseNames`.
    var displayName: String { ExerciseNames.localized(id: id) ?? name.capitalized }

    /// Libellés traduits (FR/EN/ES) du vocabulaire du dataset — cf. `ExerciseTaxonomy`.
    var categoryLabel: String { ExerciseTaxonomy.category(category) }
    var equipmentLabel: String { ExerciseTaxonomy.equipment(equipment) }
    var targetLabel: String { ExerciseTaxonomy.muscle(target) }
    var secondaryLabel: String { ExerciseTaxonomy.muscles(secondary) }

    /// Symbole SF illustrant la zone travaillée (remplace les GIFs propriétaires)
    var illustrationSymbol: String {
        Self.categorySymbol[category] ?? "figure.strengthtraining.traditional"
    }

    static let categorySymbol: [String: String] = [
        "back": "figure.climbing", "cardio": "figure.mixed.cardio",
        "chest": "figure.strengthtraining.traditional", "lower arms": "dumbbell.fill",
        "lower legs": "figure.walk", "neck": "figure.cooldown",
        "shoulders": "figure.arms.open", "upper arms": "figure.strengthtraining.functional",
        "upper legs": "figure.cross.training", "waist": "figure.core.training",
    ]

}

// MARK: - Chargement du catalogue

enum ExerciseCatalog {
    static let all: [CatalogExercise] = {
        guard let url = Bundle.main.url(forResource: "exercises_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CatalogExercise].self, from: data)
        else {
            assertionFailure("exercises_catalog.json introuvable dans le bundle")
            return []
        }
        return items.sorted { $0.name < $1.name }
    }()

    static var categories: [String] {
        Array(Set(all.map(\.category))).sorted()
    }

    static var equipments: [String] {
        Array(Set(all.map(\.equipment))).sorted()
    }

    static func find(id: String?) -> CatalogExercise? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// id catalogue → chemins d'images Free Exercise DB (domaine public).
    /// Généré par croisement des deux datasets (nom + muscle + matériel).
    static let mediaMap: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "exercise_media", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return map
    }()
}

// MARK: - Photos libres de droits (Free Exercise DB)

extension CatalogExercise {
    /// Photos début/fin de mouvement, vide si l'exercice n'est pas mappé
    var photoURLs: [URL] {
        (ExerciseCatalog.mediaMap[id] ?? []).compactMap {
            URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/\($0)")
        }
    }
}

// MARK: - Illustration vectorielle d'un exercice

/// Vignette carrée (listes, éditeurs)
struct ExerciseIllustration: View {
    let exercise: CatalogExercise
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: exercise.illustrationSymbol)
            .font(.system(size: size * 0.45))
            .foregroundStyle(Color.brand)
            .frame(width: size, height: size)
            .background(Color.brand.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
    }
}

/// Bannière photo (Free Exercise DB) avec repli sur l'illustration vectorielle
struct ExercisePhotoBanner: View {
    let exercise: CatalogExercise

    var body: some View {
        if exercise.photoURLs.isEmpty {
            ExerciseIllustrationBanner(exercise: exercise)
        } else {
            HStack(spacing: 8) {
                ForEach(exercise.photoURLs.prefix(2), id: \.self) { url in
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            Color(.secondarySystemGroupedBackground)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
        }
    }
}

/// Bannière large (fiche exercice)
struct ExerciseIllustrationBanner: View {
    let exercise: CatalogExercise

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: exercise.illustrationSymbol)
                .font(.system(size: 64))
                .foregroundStyle(Color.brand)
            Text(exercise.categoryLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color.brand.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
