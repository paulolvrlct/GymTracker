import Foundation
import FoundationModels

// MARK: - Saisie alimentaire en langage naturel

/// Transforme « deux œufs et un bol de riz » en entrées du journal alimentaire,
/// grâce au modèle de langage **embarqué** d'Apple (Foundation Models, iOS 26).
///
/// ## Pourquoi sur l'appareil
///
/// Rien ne sort du téléphone, ce qui préserve la promesse de l'app. Et le coût
/// marginal est nul : avec un Premium à achat unique, une inférence facturée
/// dans le cloud reviendrait à payer à vie pour un client qui a payé une fois.
///
/// ## La règle qui structure tout
///
/// **Le modèle n'invente aucun chiffre nutritionnel.** Il ne produit qu'un nom
/// et une quantité en grammes ; les calories et les macros sont ensuite lues
/// dans la table CIQUAL. Un modèle de quelques milliards de paramètres est bon
/// pour analyser une phrase et mauvais pour restituer des valeurs numériques —
/// et une calorie fausse dans un journal alimentaire décrédibilise tout le reste.
///
/// ## Disponibilité
///
/// iOS 26 et un appareil compatible Apple Intelligence. Ailleurs, `isAvailable`
/// renvoie `false` et l'app conserve sa recherche classique : personne ne perd
/// de fonctionnalité, certains en gagnent une.
enum NaturalFoodEntry {

    /// Un aliment reconnu dans la phrase, apparié à la table CIQUAL.
    struct Match {
        let food: CiqualFood
        let grams: Double

        var kcal: Double { grams / 100 * food.k }
    }

    /// Vrai si le modèle embarqué est utilisable ici et maintenant.
    static var isAvailable: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return SystemLanguageModel.default.isAvailable
    }

    /// Analyse une phrase et renvoie les aliments retrouvés dans CIQUAL.
    ///
    /// Les aliments que le modèle nomme mais que la base ne contient pas sont
    /// ignorés : mieux vaut proposer trois aliments justes que quatre dont un
    /// inventé.
    @available(iOS 26.0, *)
    static func parse(_ sentence: String) async throws -> [Match] {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: sentence, generating: ParsedMeal.self)

        return response.content.items.compactMap { item in
            guard item.grams > 0, let food = bestMatch(for: item.name) else { return nil }
            return Match(food: food, grams: Double(item.grams))
        }
    }

    /// Meilleure correspondance CIQUAL pour un nom d'aliment.
    ///
    /// On retient le nom le plus court parmi les résultats : la table contient
    /// beaucoup d'entrées très spécifiques (« riz blanc étuvé, cuit, non salé »)
    /// et l'entrée générique est presque toujours la bonne réponse à une phrase
    /// du quotidien.
    static func bestMatch(for name: String) -> CiqualFood? {
        let results = FoodCatalog.search(name)
        guard !results.isEmpty else { return nil }
        return results.min { $0.n.count < $1.n.count }
    }

    private static let instructions = """
        Tu extrais la liste des aliments mentionnés dans une phrase.
        La phrase peut être en français, en anglais ou en espagnol.

        Pour chaque aliment, donne :
        - son nom courant au singulier, dans la langue de la phrase, sans quantité
        - la quantité en grammes

        Si la quantité n'est pas précisée, estime une portion habituelle.
        Ignore tout ce qui n'est pas un aliment ou une boisson.

        Ne fournis jamais de calories ni de valeurs nutritionnelles :
        elles sont calculées ailleurs.
        """
}

// MARK: - Structure attendue du modèle

/// La génération guidée impose au modèle de remplir cette structure plutôt que
/// de produire du texte libre : il n'y a donc rien à analyser à la main, et
/// aucune sortie malformée à gérer.
@available(iOS 26.0, *)
@Generable
struct ParsedMeal {
    @Guide(description: "Les aliments et boissons mentionnés dans la phrase")
    let items: [ParsedFoodItem]
}

@available(iOS 26.0, *)
@Generable
struct ParsedFoodItem {
    @Guide(description: "Nom courant de l'aliment, au singulier, sans quantité")
    let name: String

    @Guide(description: "Quantité en grammes, estimée si elle n'est pas précisée")
    let grams: Int
}
