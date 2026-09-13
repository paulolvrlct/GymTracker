import Foundation
import SwiftData

// MARK: - Sauvegarde complète

/// Toutes les données de LiftRun dans un seul fichier JSON, à ranger dans
/// Fichiers › iCloud Drive et à restaurer sur un autre iPhone.
///
/// Pourquoi pas une synchronisation iCloud automatique ? CloudKit impose que
/// chaque attribut ait une valeur par défaut et que chaque relation soit
/// optionnelle : il faudrait migrer tout le modèle, avec un risque réel pour
/// les données existantes. Un fichier ne touche à rien tant qu'on ne le
/// restaure pas, et la sauvegarde iCloud de l'iPhone couvre déjà la base.
struct LiftRunBackup: Codable, Equatable {
    static let currentVersion = 1

    var version = Self.currentVersion
    var createdAt: Date
    var templates: [Template]
    var sessions: [Session]
    var runs: [Run]
    var races: [Race]
    var activities: [Activity]
    var food: [Food]
    var supplements: [Supplement]
    var intakes: [Intake]
    /// Préférences de l'app (profil, réglages) ; clés préfixées « group. »
    /// pour celles partagées avec les widgets.
    var settings: [String: Setting]

    struct Template: Codable, Equatable {
        var name: String
        var subtitle: String
        var icon: String
        var order: Int
        var exercises: [Exercise]
    }

    struct Exercise: Codable, Equatable {
        var name: String
        var targetSets: Int
        var repRange: String
        var restSeconds: Int
        var notes: String
        var order: Int
        var catalogID: String?
    }

    struct Session: Codable, Equatable {
        var date: Date
        var templateName: String
        var durationSeconds: Int
        var perceivedEffort: Int
        var sets: [SetEntry]
    }

    struct SetEntry: Codable, Equatable {
        var exerciseName: String
        var setIndex: Int
        var reps: Int
        var weight: Double
        var date: Date
    }

    struct Run: Codable, Equatable {
        var date: Date
        var distanceMeters: Double
        var durationSeconds: Int
        var routeEncoded: String
        var perceivedEffort: Int
        var healthUUID: String
        var sourceName: String
    }

    struct Race: Codable, Equatable {
        var date: Date
        var formatRaw: String
        var divisionRaw: String
        var splitsEncoded: String
    }

    struct Activity: Codable, Equatable {
        var date: Date
        var kindRaw: String
        var durationSeconds: Int
        var distanceMeters: Double
        var sourceName: String
        var healthUUID: String
    }

    struct Food: Codable, Equatable {
        var date: Date
        var name: String
        var grams: Double
        var kcalPer100: Double
        var proteinPer100: Double
        var carbsPer100: Double
        var fatPer100: Double
        var meal: String
        var category: Int
    }

    struct Supplement: Codable, Equatable {
        var name: String
        var emoji: String
        var dose: String
        var order: Int
        var isActive: Bool
        var isDaily: Bool
    }

    struct Intake: Codable, Equatable {
        var date: Date
        var supplementName: String
    }

    enum Setting: Codable, Equatable {
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
    }
}

@MainActor
enum BackupManager {

    enum BackupError: LocalizedError {
        case newerVersion

        var errorDescription: String? {
            String(localized: "Cette sauvegarde vient d'une version plus récente de LiftRun. Mets l'app à jour pour la restaurer.")
        }
    }

    static let groupPrefix = "group."
    private static let excludedPrefixes = ["debug", "Apple", "NS", "com.apple", "WebKit", "AK", "PK"]
    private static let excludedKeys: Set<String> = ["lastBackupDate"]

    // MARK: Création

    /// - Parameter domain: domaine des préférences à sauvegarder (celui de
    ///   l'app par défaut ; un domaine de test dans les tests).
    static func make(context: ModelContext, defaults: UserDefaults = .standard,
                     domain: String? = Bundle.main.bundleIdentifier,
                     now: Date = .now) -> LiftRunBackup {
        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }

        var settings: [String: LiftRunBackup.Setting] = [:]
        let values = domain.flatMap { defaults.persistentDomain(forName: $0) } ?? [:]
        for (key, value) in values
        where !excludedKeys.contains(key) && !excludedPrefixes.contains(where: key.hasPrefix) {
            if let setting = setting(from: value) { settings[key] = setting }
        }
        if let goal = SharedStore.groupDefaults?.object(forKey: WeeklyStreak.goalKey),
           let setting = setting(from: goal) {
            settings[groupPrefix + WeeklyStreak.goalKey] = setting
        }

        return LiftRunBackup(
            createdAt: now,
            templates: all(WorkoutTemplate.self).sorted { $0.order < $1.order }.map { template in
                .init(name: template.name, subtitle: template.subtitle, icon: template.icon,
                      order: template.order,
                      exercises: template.sortedExercises.map {
                          .init(name: $0.name, targetSets: $0.targetSets, repRange: $0.repRange,
                                restSeconds: $0.restSeconds, notes: $0.notes, order: $0.order,
                                catalogID: $0.catalogID)
                      })
            },
            sessions: all(WorkoutSession.self).sorted { $0.date < $1.date }.map { session in
                .init(date: session.date, templateName: session.templateName,
                      durationSeconds: session.durationSeconds,
                      perceivedEffort: session.perceivedEffort,
                      sets: session.sets
                        .sorted { ($0.exerciseName, $0.setIndex) < ($1.exerciseName, $1.setIndex) }
                        .map {
                            .init(exerciseName: $0.exerciseName, setIndex: $0.setIndex,
                                  reps: $0.reps, weight: $0.weight, date: $0.date)
                        })
            },
            runs: all(RunSession.self).sorted { $0.date < $1.date }.map {
                .init(date: $0.date, distanceMeters: $0.distanceMeters,
                      durationSeconds: $0.durationSeconds, routeEncoded: $0.routeEncoded,
                      perceivedEffort: $0.perceivedEffort, healthUUID: $0.healthUUID,
                      sourceName: $0.sourceName)
            },
            races: all(HybridRaceResult.self).sorted { $0.date < $1.date }.map {
                .init(date: $0.date, formatRaw: $0.formatRaw, divisionRaw: $0.divisionRaw,
                      splitsEncoded: $0.splitsEncoded)
            },
            activities: all(ImportedActivity.self).sorted { $0.date < $1.date }.map {
                .init(date: $0.date, kindRaw: $0.kindRaw, durationSeconds: $0.durationSeconds,
                      distanceMeters: $0.distanceMeters, sourceName: $0.sourceName,
                      healthUUID: $0.healthUUID)
            },
            food: all(FoodEntry.self).sorted { $0.date < $1.date }.map {
                .init(date: $0.date, name: $0.name, grams: $0.grams, kcalPer100: $0.kcalPer100,
                      proteinPer100: $0.proteinPer100, carbsPer100: $0.carbsPer100,
                      fatPer100: $0.fatPer100, meal: $0.meal, category: $0.category)
            },
            supplements: all(Supplement.self).sorted { $0.order < $1.order }.map {
                .init(name: $0.name, emoji: $0.emoji, dose: $0.dose, order: $0.order,
                      isActive: $0.isActive, isDaily: $0.isDaily)
            },
            intakes: all(SupplementIntake.self).sorted { $0.date < $1.date }.map {
                .init(date: $0.date, supplementName: $0.supplementName)
            },
            settings: settings)
    }

    private static func setting(from value: Any) -> LiftRunBackup.Setting? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return CFNumberIsFloatType(number) ? .double(number.doubleValue) : .int(number.intValue)
        case let text as String:
            return .string(text)
        default:
            return nil
        }
    }

    // MARK: Fichier

    static func encode(_ backup: LiftRunBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> LiftRunBackup {
        let backup = try JSONDecoder().decode(LiftRunBackup.self, from: data)
        guard backup.version <= LiftRunBackup.currentVersion else { throw BackupError.newerVersion }
        return backup
    }

    /// « LiftRun-sauvegarde-2026-09-13.json », dans le dossier temporaire,
    /// prêt à être enregistré par la feuille de partage.
    static func write(_ backup: LiftRunBackup) throws -> URL {
        let day = backup.createdAt.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiftRun-sauvegarde-\(day).json")
        try encode(backup).write(to: url, options: .atomic)
        return url
    }

    // MARK: Restauration

    /// Remplace toutes les données par celles de la sauvegarde. À n'appeler
    /// qu'avec une sauvegarde déjà décodée : un fichier illisible n'efface rien.
    static func restore(_ backup: LiftRunBackup, into context: ModelContext,
                        defaults: UserDefaults = .standard) throws {
        func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
            for item in try context.fetch(FetchDescriptor<T>()) { context.delete(item) }
        }
        try deleteAll(SetRecord.self)
        try deleteAll(WorkoutSession.self)
        try deleteAll(ExerciseTemplate.self)
        try deleteAll(WorkoutTemplate.self)
        try deleteAll(RunSession.self)
        try deleteAll(HybridRaceResult.self)
        try deleteAll(ImportedActivity.self)
        try deleteAll(FoodEntry.self)
        try deleteAll(Supplement.self)
        try deleteAll(SupplementIntake.self)

        for item in backup.templates {
            let template = WorkoutTemplate(name: item.name, subtitle: item.subtitle,
                                           icon: item.icon, order: item.order)
            template.exercises = item.exercises.map {
                ExerciseTemplate(name: $0.name, targetSets: $0.targetSets, repRange: $0.repRange,
                                 restSeconds: $0.restSeconds, notes: $0.notes, order: $0.order,
                                 catalogID: $0.catalogID)
            }
            context.insert(template)
        }
        for item in backup.sessions {
            let session = WorkoutSession(date: item.date, templateName: item.templateName,
                                         durationSeconds: item.durationSeconds)
            session.perceivedEffort = item.perceivedEffort
            context.insert(session)
            for set in item.sets {
                let record = SetRecord(exerciseName: set.exerciseName, setIndex: set.setIndex,
                                       reps: set.reps, weight: set.weight, date: set.date)
                record.session = session
                context.insert(record)
            }
        }
        for item in backup.runs {
            let run = RunSession(date: item.date, distanceMeters: item.distanceMeters,
                                 durationSeconds: item.durationSeconds, routeEncoded: item.routeEncoded)
            run.perceivedEffort = item.perceivedEffort
            run.healthUUID = item.healthUUID
            run.sourceName = item.sourceName
            context.insert(run)
        }
        for item in backup.races {
            let race = HybridRaceResult(date: item.date, formatRaw: item.formatRaw,
                                        divisionRaw: item.divisionRaw, splits: [])
            race.splitsEncoded = item.splitsEncoded
            context.insert(race)
        }
        for item in backup.activities {
            context.insert(ImportedActivity(date: item.date, kindRaw: item.kindRaw,
                                            durationSeconds: item.durationSeconds,
                                            distanceMeters: item.distanceMeters,
                                            sourceName: item.sourceName, healthUUID: item.healthUUID))
        }
        for item in backup.food {
            context.insert(FoodEntry(date: item.date, name: item.name, grams: item.grams,
                                     kcalPer100: item.kcalPer100, proteinPer100: item.proteinPer100,
                                     carbsPer100: item.carbsPer100, fatPer100: item.fatPer100,
                                     meal: item.meal, category: item.category))
        }
        for item in backup.supplements {
            context.insert(Supplement(name: item.name, emoji: item.emoji, dose: item.dose,
                                      order: item.order, isActive: item.isActive, isDaily: item.isDaily))
        }
        for item in backup.intakes {
            context.insert(SupplementIntake(date: item.date, supplementName: item.supplementName))
        }
        try context.save()

        for (key, setting) in backup.settings {
            if key.hasPrefix(groupPrefix) {
                if let group = SharedStore.groupDefaults {
                    apply(setting, forKey: String(key.dropFirst(groupPrefix.count)), to: group)
                }
            } else {
                apply(setting, forKey: key, to: defaults)
            }
        }
    }

    private static func apply(_ setting: LiftRunBackup.Setting, forKey key: String, to defaults: UserDefaults) {
        switch setting {
        case .bool(let value): defaults.set(value, forKey: key)
        case .int(let value): defaults.set(value, forKey: key)
        case .double(let value): defaults.set(value, forKey: key)
        case .string(let value): defaults.set(value, forKey: key)
        }
    }
}
