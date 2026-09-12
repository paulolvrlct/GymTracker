#if DEBUG
import Foundation
import SwiftData

// MARK: - Données de démonstration (Debug uniquement)

/// Deux semaines d'entraînement hybride fictif : de quoi vérifier chaque écran
/// sur le simulateur, et produire des captures d'écran réalistes.
///
/// Activé par l'argument de lancement `-seedDemoData YES`, et seulement sur une
/// base sans aucune séance : impossible d'écraser un vrai historique. Absent des
/// builds Release (donc de l'App Store).
enum DemoData {

    static func seedIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedDemoData") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 0
        guard existing == 0 else { return }

        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.order)]))) ?? []
        guard templates.count >= 3 else { return }

        let now = Date.now
        func daysAgo(_ days: Double, hour: Int) -> Date {
            let day = Calendar.current.date(byAdding: .day, value: -Int(days), to: now) ?? now
            return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }

        // Rotation A / B / C avec progression de charge d'une semaine à l'autre.
        let plan: [(template: Int, days: Double, progress: Double)] = [
            (0, 13, 0), (1, 11, 0), (2, 10, 0),
            (0, 6, 2.5), (1, 4, 2.5), (2, 3, 0),
            (0, 2, 5),
        ]
        for entry in plan {
            let template = templates[entry.template]
            let date = daysAgo(entry.days, hour: 18)
            let session = WorkoutSession(date: date, templateName: template.name,
                                         durationSeconds: 55 * 60)
            context.insert(session)
            for (index, exercise) in template.sortedExercises.enumerated() {
                let base = [50.0, 22, 60, 35, 30, 12, 15, 20][index % 8]
                for set in 1...exercise.targetSets {
                    let record = SetRecord(exerciseName: exercise.name, setIndex: set,
                                           reps: set == exercise.targetSets ? 7 : 8,
                                           weight: base + entry.progress, date: date)
                    record.session = session
                    context.insert(record)
                }
            }
        }

        // Courses : endurance, fractionné, sortie longue… la dernière hier soir.
        let runs: [(days: Double, km: Double, pace: Double)] = [
            (12, 8, 330), (9, 6, 260), (7, 12, 345), (1, 10, 315),
        ]
        for run in runs {
            context.insert(RunSession(date: daysAgo(run.days, hour: 19),
                                      distanceMeters: run.km * 1000,
                                      durationSeconds: Int(run.km * run.pace)))
        }

        // Une demi-course hybride la semaine dernière : un premier record à battre.
        context.insert(HybridRaceResult(date: daysAgo(8, hour: 10),
                                        formatRaw: HybridRace.Format.half.rawValue,
                                        divisionRaw: HybridRace.Division.openWomen.rawValue,
                                        splits: [282, 265, 301, 214, 290, 248, 296, 305]))

        if VMAStore.value == nil { VMAStore.save(15) }
        context.saveLogging()
    }
}
#endif
