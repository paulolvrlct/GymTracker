import Foundation

// MARK: - Séance en cours, sauvegardée

/// Une séance commencée mais pas terminée, conservée hors de la mémoire vive.
///
/// iOS ferme une app en arrière-plan quand il a besoin de place, et un appel
/// entrant ou un faux mouvement suffisent à la quitter. Sans cette sauvegarde,
/// toutes les séries saisies disparaissaient. Ici, chaque série validée est
/// écrite sur le disque : au relancement, la séance reprend telle quelle.
struct WorkoutDraft: Codable, Equatable {

    struct Exercise: Codable, Equatable {
        var name: String
        var catalogID: String?
        var sets: Int
        var repRange: String
        var restSeconds: Int
        var notes: String
    }

    struct Set: Codable, Equatable {
        var exerciseName: String
        var reps: Int
        var weight: Double
    }

    var templateName: String
    var startDate: Date
    /// Les exercices tels qu'ils étaient : remplacements et séance express compris.
    var exercises: [Exercise]
    var sets: [Set]
    var timeBudget: Int?

    /// Une séance oubliée depuis la veille ne se rouvre pas toute seule : au-delà,
    /// elle serait fausse (durée absurde, charges d'un autre jour).
    static let maxAge: TimeInterval = 12 * 3600

    func isFresh(now: Date = .now) -> Bool {
        now.timeIntervalSince(startDate) < Self.maxAge
    }
}

enum WorkoutDraftStore {
    static let key = "workoutDraft"

    private static var shared: UserDefaults { SharedStore.groupDefaults ?? .standard }

    static func save(_ draft: WorkoutDraft, to defaults: UserDefaults? = nil) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        (defaults ?? shared).set(data, forKey: key)
    }

    /// La séance en cours, si elle est encore d'actualité. Une séance trop
    /// vieille est effacée au passage.
    static func load(from defaults: UserDefaults? = nil, now: Date = .now) -> WorkoutDraft? {
        let store = defaults ?? shared
        guard let data = store.data(forKey: key),
              let draft = try? JSONDecoder().decode(WorkoutDraft.self, from: data) else { return nil }
        guard draft.isFresh(now: now) else {
            clear(from: store)
            return nil
        }
        return draft
    }

    static func clear(from defaults: UserDefaults? = nil) {
        (defaults ?? shared).removeObject(forKey: key)
    }
}
