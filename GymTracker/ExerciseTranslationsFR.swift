import Foundation

/// Traduction française du catalogue d'exercices : nom et étapes d'exécution.
///
/// Le dataset source (hasaneyldrm/exercises-dataset) n'existe qu'en anglais :
/// `exercises_fr.json` en fournit une traduction complète, au tutoiement,
/// indexée par ID catalogue. Les exercices du programme pré-chargé y ont des
/// étapes réécrites à la main, plus directives que la version du dataset.
///
/// Réservée à une interface en français : dans les autres langues, tout renvoie
/// nil et l'UI garde le texte source anglais (avec le badge « EN »).
enum ExerciseTranslationsFR {

    struct Entry: Decodable {
        let name: String
        let steps: [String]
    }

    /// Chargé à la première consultation — jamais hors interface française,
    /// puisque chaque accès passe d'abord par `isFrenchUI`.
    private static let entries: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "exercises_fr", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else {
            assertionFailure("exercises_fr.json introuvable dans le bundle")
            return [:]
        }
        return decoded
    }()

    /// Étapes en français, ou nil hors interface française.
    static func steps(for catalogID: String?) -> [String]? {
        guard isFrenchUI, let catalogID else { return nil }
        return entries[catalogID]?.steps
    }

    /// Nom en français, ou nil hors interface française.
    static func name(for catalogID: String) -> String? {
        guard isFrenchUI else { return nil }
        return entries[catalogID]?.name
    }

    /// Langue effectivement retenue pour le bundle (et non la région) : couvre
    /// « fr », mais aussi « fr-CA », « fr-BE »… Figée au lancement, comme la
    /// langue de l'app sur iOS.
    private static let isFrenchUI: Bool =
        Bundle.main.preferredLocalizations.first?.hasPrefix("fr") ?? false
}
