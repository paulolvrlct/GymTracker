import Foundation
import SwiftData
import os

// MARK: - Sauvegarde SwiftData avec remontée d'erreur

extension ModelContext {
    /// Sauvegarde en journalisant l'échec (au lieu de l'avaler avec `try?`).
    /// Retourne `false` si l'enregistrement a échoué.
    @discardableResult
    func saveLogging(_ context: String = #function) -> Bool {
        do {
            try save()
            return true
        } catch {
            Logger(subsystem: "fr.devshield.gymtracker", category: "persistence")
                .error("Échec d'enregistrement (\(context, privacy: .public)) : \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

// MARK: - Séance type (template)

@Model
final class WorkoutTemplate {
    var name: String
    var subtitle: String
    var icon: String
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.workout)
    var exercises: [ExerciseTemplate] = []

    init(name: String, subtitle: String = "", icon: String = "dumbbell.fill", order: Int = 0) {
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.order = order
    }

    var sortedExercises: [ExerciseTemplate] {
        exercises.sorted { $0.order < $1.order }
    }
}

// MARK: - Exercice d'une séance type

@Model
final class ExerciseTemplate {
    var name: String
    var targetSets: Int
    var repRange: String        // ex : "6-8"
    var restSeconds: Int
    var notes: String
    var order: Int
    /// ID de l'exercice dans le catalogue embarqué (GIF, instructions, muscles)
    var catalogID: String?
    var workout: WorkoutTemplate?

    init(name: String, targetSets: Int, repRange: String, restSeconds: Int, notes: String = "", order: Int = 0, catalogID: String? = nil) {
        self.name = name
        self.targetSets = targetSets
        self.repRange = repRange
        self.restSeconds = restSeconds
        self.notes = notes
        self.order = order
        self.catalogID = catalogID
    }
}

// MARK: - Séance réalisée (historique)

@Model
final class WorkoutSession {
    var date: Date
    var templateName: String
    var durationSeconds: Int
    /// Ressenti de fin de séance, de 1 à 10 (0 = non renseigné).
    var perceivedEffort: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.session)
    var sets: [SetRecord] = []

    init(date: Date = .now, templateName: String, durationSeconds: Int = 0) {
        self.date = date
        self.templateName = templateName
        self.durationSeconds = durationSeconds
    }

    var totalVolume: Double {
        sets.reduce(0) { $0 + Double($1.reps) * $1.weight }
    }
}

// MARK: - Course enregistrée (mode running)

@Model
final class RunSession {
    var date: Date
    var distanceMeters: Double
    var durationSeconds: Int
    /// Tracé GPS encodé : suite de "lat,lon" séparés par ";"
    var routeEncoded: String
    /// Ressenti de fin de course, de 1 à 10 (0 = non renseigné).
    var perceivedEffort: Int = 0
    /// Course importée d'Apple Santé (montre, autre app) : UUID de
    /// l'entraînement, pour ne jamais l'importer deux fois. Vide pour une
    /// course suivie par LiftRun.
    var healthUUID: String = ""
    /// App ou appareil d'origine d'une course importée (« Apple Watch »).
    var sourceName: String = ""

    init(date: Date = .now, distanceMeters: Double = 0, durationSeconds: Int = 0, routeEncoded: String = "") {
        self.date = date
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.routeEncoded = routeEncoded
    }

    /// Allure moyenne en secondes par km
    var averagePaceSecPerKm: Double {
        guard distanceMeters > 0 else { return 0 }
        return Double(durationSeconds) / (distanceMeters / 1000)
    }

    var distanceKm: Double { distanceMeters / 1000 }

    /// Coordonnées décodées [(lat, lon)]
    var routePoints: [(lat: Double, lon: Double)] {
        routeEncoded.split(separator: ";").compactMap { pair in
            let c = pair.split(separator: ",")
            guard c.count == 2, let lat = Double(c[0]), let lon = Double(c[1]) else { return nil }
            return (lat, lon)
        }
    }
}

// MARK: - Activité importée d'Apple Santé

/// Entraînement fait avec une montre ou une autre app (vélo, natation…), lu
/// dans Apple Santé. Les courses importées deviennent des `RunSession` ; le
/// reste arrive ici, pour peser dans la forme du jour et la régularité.
@Model
final class ImportedActivity {
    var date: Date
    /// Famille d'activité (`ImportedKind.rawValue` : « cycling », « swimming »…),
    /// stockée en texte pour que le widget lise la base sans connaître le moteur.
    var kindRaw: String
    var durationSeconds: Int
    var distanceMeters: Double
    var sourceName: String
    /// UUID de l'entraînement dans Santé : évite de l'importer deux fois.
    var healthUUID: String

    init(date: Date, kindRaw: String, durationSeconds: Int, distanceMeters: Double,
         sourceName: String, healthUUID: String) {
        self.date = date
        self.kindRaw = kindRaw
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.sourceName = sourceName
        self.healthUUID = healthUUID
    }
}

// MARK: - Entrée du journal alimentaire (Premium)

@Model
final class FoodEntry {
    var date: Date
    var name: String
    var grams: Double
    // Valeurs pour 100 g figées à la saisie (le catalogue peut évoluer)
    var kcalPer100: Double
    var proteinPer100: Double
    var carbsPer100: Double
    var fatPer100: Double
    var meal: String
    var category: Int = 8      // FoodCategory (défaut : divers, pour la migration)
    /// UUID des échantillons Apple Santé liés (séparés par des virgules),
    /// pour supprimer les données Santé avec l'entrée
    var healthIDs: String = ""

    init(date: Date = .now, name: String, grams: Double,
         kcalPer100: Double, proteinPer100: Double,
         carbsPer100: Double, fatPer100: Double, meal: String, category: Int = 8) {
        self.date = date
        self.name = name
        self.grams = grams
        self.kcalPer100 = kcalPer100
        self.proteinPer100 = proteinPer100
        self.carbsPer100 = carbsPer100
        self.fatPer100 = fatPer100
        self.meal = meal
        self.category = category
    }

    var kcal: Double { kcalPer100 * grams / 100 }
    var protein: Double { proteinPer100 * grams / 100 }
    var carbs: Double { carbsPer100 * grams / 100 }
    var fat: Double { fatPer100 * grams / 100 }
}

// MARK: - Compléments quotidiens (checklist)

@Model
final class Supplement {
    var name: String
    var emoji: String
    var dose: String          // libre : « 5 g », « 1 gélule », « 30 g »
    var order: Int
    var isActive: Bool
    // quotidien (compte dans la routine et la série) vs optionnel (whey,
    // pre-workout… pris quand on veut, sans casser la régularité).
    var isDaily: Bool = true

    init(name: String, emoji: String = "💊", dose: String = "", order: Int = 0,
         isActive: Bool = true, isDaily: Bool = true) {
        self.name = name
        self.emoji = emoji
        self.dose = dose
        self.order = order
        self.isActive = isActive
        self.isDaily = isDaily
    }
}

/// Une prise cochée, un jour donné (date ramenée au début de journée)
@Model
final class SupplementIntake {
    var date: Date
    var supplementName: String

    init(date: Date, supplementName: String) {
        self.date = Calendar.current.startOfDay(for: date)
        self.supplementName = supplementName
    }
}

// MARK: - Conteneur SwiftData partagé (App Group)
// Ce fichier appartient aux DEUX cibles : l'app et la widget extension lisent
// la même base via le conteneur du groupe `group.fr.devshield.gymtracker`.

enum SharedStore {
    static let appGroupID = "group.fr.devshield.gymtracker"

    /// Préférences partagées app ↔ widgets
    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
    /// Objectif kcal du jour, publié par l'app pour le widget calories
    static let nutritionTargetKey = "widget.nutritionTargetKcal"

    static var schema: Schema {
        Schema([WorkoutTemplate.self, ExerciseTemplate.self,
                WorkoutSession.self, SetRecord.self, RunSession.self,
                FoodEntry.self, Supplement.self, SupplementIntake.self,
                HybridRaceResult.self, ImportedActivity.self])
    }

    static func makeContainer() throws -> ModelContainer {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            // Entitlement App Group absent : repli sur la base locale historique
            return try ModelContainer(for: schema)
        }
        migrateLegacyStoreIfNeeded(to: groupURL)
        let config = ModelConfiguration(url: groupURL.appendingPathComponent("GymTracker.store"))
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Copie unique de l'ancienne base locale (avant App Group) vers le conteneur partagé,
    /// pour ne pas perdre les données déjà enregistrées sur l'appareil.
    private static func migrateLegacyStoreIfNeeded(to groupURL: URL) {
        let fm = FileManager.default
        let target = groupURL.appendingPathComponent("GymTracker.store")
        guard !fm.fileExists(atPath: target.path) else { return }
        let legacy = URL.applicationSupportDirectory.appending(path: "default.store")
        guard fm.fileExists(atPath: legacy.path) else { return }
        for suffix in ["", "-shm", "-wal"] {
            try? fm.copyItem(
                at: URL.applicationSupportDirectory.appending(path: "default.store" + suffix),
                to: groupURL.appendingPathComponent("GymTracker.store" + suffix)
            )
        }
    }
}

// MARK: - Formatage allure / durée

enum PaceFormatter {
    /// 372 s/km -> "6'12\"/km"
    static func string(secPerKm: Double) -> String {
        guard secPerKm > 0, secPerKm.isFinite else { return "-" }
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d'%02d\"/km", m, s)
    }

    /// 3725 s -> "1:02:05" ou "12:05"
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Série enregistrée

@Model
final class SetRecord {
    var exerciseName: String
    var setIndex: Int
    var reps: Int
    var weight: Double          // kg — 0 pour le poids du corps
    var date: Date
    var session: WorkoutSession?

    init(exerciseName: String, setIndex: Int, reps: Int, weight: Double, date: Date = .now) {
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.date = date
    }
}

// MARK: - Régularité hebdomadaire (partagée app ↔ widget)

/// Objectif de jours actifs par semaine, et nombre de semaines d'affilée où il
/// a été tenu.
///
/// Remplace la série de jours consécutifs, qui punissait le repos : une série
/// quotidienne pousse à s'entraîner fatigué pour ne pas « casser la chaîne »,
/// exactement l'inverse de ce que conseille la carte « Aujourd'hui ». À la
/// semaine, un jour off ne coûte rien — c'est le choix de Strava, et celui qui
/// tient sur la durée.
enum WeeklyStreak {

    static let goalKey = "weeklyGoalDays"
    static let defaultGoal = 3
    static let goalRange = 1...7

    /// Objectif enregistré dans les préférences partagées (lu aussi par le widget).
    static var goal: Int {
        let stored = SharedStore.groupDefaults?.integer(forKey: goalKey) ?? 0
        return goalRange.contains(stored) ? stored : defaultGoal
    }

    struct Status: Equatable {
        /// Semaines d'affilée avec l'objectif tenu. La semaine en cours compte
        /// dès qu'elle est validée ; tant qu'elle ne l'est pas, elle ne casse
        /// rien : elle n'est pas finie.
        let weeks: Int
        /// Jours actifs distincts depuis lundi.
        let thisWeek: Int
        let goal: Int

        var isThisWeekDone: Bool { thisWeek >= goal }
        var progress: Double { min(1, Double(thisWeek) / Double(max(goal, 1))) }
    }

    /// Un jour avec une séance ET une course ne compte qu'une fois : on mesure
    /// la régularité, pas le nombre d'activités.
    static func status(activityDates: [Date], goal: Int, now: Date = .now,
                       calendar: Calendar = .current) -> Status {
        let days = Set(activityDates.map { calendar.startOfDay(for: $0) })

        func activeDays(inWeekOf date: Date) -> Int {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
            // Fin exclusive : `DateInterval.contains` inclut sa borne de fin, ce
            // qui comptait le lundi 0 h dans la semaine précédente aussi.
            return days.filter { $0 >= week.start && $0 < week.end }.count
        }

        let thisWeek = activeDays(inWeekOf: now)
        var weeks = thisWeek >= goal ? 1 : 0
        var reference = now
        // Borne de sécurité : dix ans de semaines.
        for _ in 0..<520 {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: reference),
                  activeDays(inWeekOf: previous) >= goal else { break }
            weeks += 1
            reference = previous
        }
        return Status(weeks: weeks, thisWeek: thisWeek, goal: goal)
    }
}

// MARK: - Simulation de course hybride

/// Une simulation terminée : le temps de chaque segment (course, atelier,
/// course…). Format et catégorie sont stockés en texte pour que le widget,
/// qui ne connaît pas `HybridRace`, puisse lire la base sans rien de plus.
@Model
final class HybridRaceResult {
    var date: Date
    var formatRaw: String
    var divisionRaw: String
    /// Durées des segments en secondes, séparées par des virgules.
    var splitsEncoded: String

    init(date: Date = .now, formatRaw: String, divisionRaw: String, splits: [Int]) {
        self.date = date
        self.formatRaw = formatRaw
        self.divisionRaw = divisionRaw
        self.splitsEncoded = splits.map(String.init).joined(separator: ",")
    }

    var splits: [Int] { splitsEncoded.split(separator: ",").compactMap { Int($0) } }
    var totalSeconds: Int { splits.reduce(0, +) }
}

// MARK: - Forme du jour, pour le widget (partagé app ↔ widget)

/// Un point de la prévision de forme : note et séance conseillée à une heure
/// donnée.
struct ReadinessForecastPoint: Codable, Hashable {
    let date: Date
    let score: Int
    let title: String
}

/// Prévision de forme publiée par l'app pour le widget.
///
/// Le widget n'a ni le catalogue d'exercices ni le moteur de récupération.
/// Plutôt que de les dupliquer, l'app calcule d'avance la forme heure par
/// heure pour les deux prochains jours — la fatigue ne fait que décroître
/// tant qu'on ne s'entraîne pas — et le widget affiche le point de l'heure.
/// C'est exactement le modèle des timelines WidgetKit.
enum ReadinessForecast {
    static let key = "widget.readinessForecast"
    static let widgetKind = "ReadinessWidget"

    static func save(_ points: [ReadinessForecastPoint]) {
        guard let data = try? JSONEncoder().encode(points) else { return }
        SharedStore.groupDefaults?.set(data, forKey: key)
    }

    static func load() -> [ReadinessForecastPoint] {
        guard let data = SharedStore.groupDefaults?.data(forKey: key),
              let points = try? JSONDecoder().decode([ReadinessForecastPoint].self, from: data)
        else { return [] }
        return points
    }
}
