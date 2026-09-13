import AppIntents
import SwiftUI

// MARK: - Demandes venues de l'extérieur

/// Siri, l'app Raccourcis, le bouton Action et le widget demandent une action ;
/// l'app l'exécute dès qu'elle est affichée, avec l'historique à jour.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Request: Equatable {
        /// La séance conseillée par la forme du jour.
        case startToday
        /// L'onglet Course, prêt à démarrer.
        case openRun
    }

    @Published var pending: Request?

    private init() {}

    /// `gymtracker://today` (widget « Forme du jour ») et `gymtracker://run`
    /// (widget raccourci).
    func handle(_ url: URL) {
        guard url.scheme == "gymtracker" else { return }
        switch url.host {
        case "today": pending = .startToday
        case "run": pending = .openRun
        default: break
        }
    }
}

// MARK: - Intents

struct StartTodayWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Lancer la séance du jour"
    static let description = IntentDescription("Ouvre LiftRun et démarre la séance conseillée par ta forme du jour.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pending = .startToday
        return .result()
    }
}

struct StartRunIntent: AppIntent {
    static let title: LocalizedStringResource = "Démarrer une course"
    static let description = IntentDescription("Ouvre LiftRun sur l'onglet Course.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pending = .openRun
        return .result()
    }
}

// MARK: - Raccourcis Siri

/// Disponibles sans configuration : « Dis Siri, lance ma séance du jour dans
/// LiftRun ». Ils apparaissent aussi dans l'app Raccourcis et peuvent être
/// placés sur le bouton Action.
struct LiftRunShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTodayWorkoutIntent(),
                    phrases: ["Lance ma séance du jour dans \(.applicationName)",
                              "Séance du jour avec \(.applicationName)",
                              "Démarre ma séance \(.applicationName)"],
                    shortTitle: "Séance du jour",
                    systemImageName: "dumbbell.fill")
        AppShortcut(intent: StartRunIntent(),
                    phrases: ["Démarre une course avec \(.applicationName)",
                              "Lance une course dans \(.applicationName)"],
                    shortTitle: "Course",
                    systemImageName: "figure.run")
    }
}
