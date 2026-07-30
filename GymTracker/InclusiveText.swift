import Foundation

// MARK: - Accords selon le genre de l'utilisateur

/// Les String Catalogs d'Apple savent varier par pluriel et par appareil, mais
/// pas selon le genre de la personne à qui l'on parle : on choisit donc la
/// variante à l'exécution, parmi trois clés explicites.
///
/// Pour « Non précisé », on n'écrit pas « prêt·e » : le point médian se lit mal
/// et VoiceOver l'énonce caractère par caractère. On reformule pour éviter
/// l'accord (« Envie de courir ? ») — c'est plus lisible pour tout le monde.
///
/// L'anglais n'accordant pas ses adjectifs, ses trois variantes sont identiques :
/// c'est voulu, et ça garde une seule façon d'écrire ces phrases dans le code.
///
/// Le genre est passé en **paramètre** plutôt que lu depuis les UserDefaults :
/// la vue appelante doit l'observer via `@AppStorage("profileSex")`, ce qui
/// garantit un rafraîchissement immédiat quand l'utilisateur le change.
enum InclusiveText {

    static func readyToRun(_ sex: UserSex) -> String {
        switch sex {
        case .male:        String(localized: "inclusive.readyToRun.m")
        case .female:      String(localized: "inclusive.readyToRun.f")
        case .unspecified: String(localized: "inclusive.readyToRun.n")
        }
    }

    static func backAtItToday(_ sex: UserSex) -> String {
        switch sex {
        case .male:        String(localized: "inclusive.backAtItToday.m")
        case .female:      String(localized: "inclusive.backAtItToday.f")
        case .unspecified: String(localized: "inclusive.backAtItToday.n")
        }
    }

    static func welcome(_ sex: UserSex) -> String {
        switch sex {
        case .male:        String(localized: "inclusive.welcome.m")
        case .female:      String(localized: "inclusive.welcome.f")
        case .unspecified: String(localized: "inclusive.welcome.n")
        }
    }

    static func welcomeToApp(_ sex: UserSex) -> String {
        switch sex {
        case .male:        String(localized: "inclusive.welcomeToApp.m")
        case .female:      String(localized: "inclusive.welcomeToApp.f")
        case .unspecified: String(localized: "inclusive.welcomeToApp.n")
        }
    }
}

extension UserSex {
    /// Reconstruit le genre depuis la valeur brute persistée
    /// (`@AppStorage("profileSex")`), avec repli sur « non précisé ».
    init(stored raw: String) {
        self = UserSex(rawValue: raw) ?? .unspecified
    }
}
