import Foundation

// MARK: - Bilan de la semaine (à partager)

/// Les 7 derniers jours en quelques chiffres, pour l'image à partager.
///
/// Le partage est le moteur de croissance des apps de sport : c'est la carte
/// de fin d'activité publiée en story qui a fait connaître Strava. LiftRun n'a
/// ni compte ni réseau social — et n'en veut pas —, mais une image qui montre
/// muscu ET course sur une même carte est unique, et se partage partout.
///
/// Sept jours glissants plutôt que la semaine calendaire : partagé un lundi
/// matin, le bilan de la semaine en cours serait vide.
struct WeeklyRecap: Equatable {

    struct LoggedSet {
        let exercise: String
        let reps: Int
        let weight: Double
        let date: Date
    }

    let start: Date
    let end: Date
    let workouts: Int
    let runs: Int
    let races: Int
    let kilometres: Double
    let tonnes: Double
    let activeDays: Int
    /// Exercices dont le 1RM estimé a battu tout ce qui précédait la semaine.
    let personalRecords: Int
    let streakWeeks: Int

    var isEmpty: Bool { workouts + runs + races == 0 }

    static func make(workouts: [(date: Date, volumeKg: Double)],
                     runs: [(date: Date, km: Double)],
                     raceDates: [Date],
                     sets: [LoggedSet],
                     streakWeeks: Int,
                     now: Date = .now,
                     calendar: Calendar = .current) -> WeeklyRecap {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: now) ?? now)
        func inWeek(_ date: Date) -> Bool { date >= start && date <= now }

        let weekWorkouts = workouts.filter { inWeek($0.date) }
        let weekRuns = runs.filter { inWeek($0.date) }
        let weekRaces = raceDates.filter(inWeek)
        let days = Set((weekWorkouts.map(\.date) + weekRuns.map(\.date) + weekRaces)
            .map { calendar.startOfDay(for: $0) })

        return WeeklyRecap(
            start: start, end: now,
            workouts: weekWorkouts.count,
            runs: weekRuns.count,
            races: weekRaces.count,
            kilometres: weekRuns.reduce(0) { $0 + $1.km },
            tonnes: weekWorkouts.reduce(0) { $0 + $1.volumeKg } / 1000,
            activeDays: days.count,
            personalRecords: records(in: sets, since: start, until: now),
            streakWeeks: streakWeeks)
    }

    /// Un record ne compte que s'il y avait quelque chose à battre : la
    /// première fois qu'on fait un exercice n'est pas un record.
    static func records(in sets: [LoggedSet], since start: Date, until end: Date) -> Int {
        func estimate(_ set: LoggedSet) -> Double { set.weight * (1 + Double(set.reps) / 30) }
        let byExercise = Dictionary(grouping: sets.filter { $0.weight > 0 }, by: \.exercise)
        return byExercise.values.filter { history in
            let before = history.filter { $0.date < start }.map(estimate).max()
            let during = history.filter { $0.date >= start && $0.date <= end }.map(estimate).max()
            guard let before, let during else { return false }
            return during > before
        }.count
    }
}
