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

    /// Un jour de la frise : ce qui a été fait ce jour-là.
    struct Day: Equatable {
        let date: Date
        let lifted: Bool
        let ran: Bool
        let raced: Bool

        var isActive: Bool { lifted || ran || raced }
    }

    /// Un record battu cette semaine, avec la série qui l'a établi.
    struct Record: Equatable {
        let exercise: String
        let weight: Double
        let reps: Int
    }

    let start: Date
    let end: Date
    let workouts: Int
    let runs: Int
    let races: Int
    let kilometres: Double
    let longestRunKm: Double
    let tonnes: Double
    let activeDays: Int
    /// Nombre d'exercices dont le 1RM estimé a battu tout ce qui précédait.
    let personalRecords: Int
    /// Les deux records les plus marquants (plus forte progression relative).
    let topRecords: [Record]
    /// Les 7 jours, du plus ancien au plus récent.
    let days: [Day]
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

        let days: [Day] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            func same(_ date: Date) -> Bool { calendar.isDate(date, inSameDayAs: day) }
            return Day(date: day,
                       lifted: weekWorkouts.contains { same($0.date) },
                       ran: weekRuns.contains { same($0.date) },
                       raced: weekRaces.contains(where: same))
        }

        let records = records(in: sets, since: start, until: now)

        return WeeklyRecap(
            start: start, end: now,
            workouts: weekWorkouts.count,
            runs: weekRuns.count,
            races: weekRaces.count,
            kilometres: weekRuns.reduce(0) { $0 + $1.km },
            longestRunKm: weekRuns.map(\.km).max() ?? 0,
            tonnes: weekWorkouts.reduce(0) { $0 + $1.volumeKg } / 1000,
            activeDays: days.filter(\.isActive).count,
            personalRecords: records.count,
            topRecords: Array(records.prefix(2)),
            days: days,
            streakWeeks: streakWeeks)
    }

    /// Records de la semaine, du plus marquant au moins marquant.
    ///
    /// Un record ne compte que s'il y avait quelque chose à battre : la
    /// première fois qu'on fait un exercice n'est pas un record. Le classement
    /// se fait sur la progression relative du 1RM estimé : +5 kg au curl
    /// impressionnent davantage que +5 kg au soulevé de terre.
    static func records(in sets: [LoggedSet], since start: Date, until end: Date) -> [Record] {
        func estimate(_ set: LoggedSet) -> Double { set.weight * (1 + Double(set.reps) / 30) }
        let byExercise = Dictionary(grouping: sets.filter { $0.weight > 0 }, by: \.exercise)

        let ranked: [(record: Record, gain: Double)] = byExercise.compactMap { exercise, history in
            let before = history.filter { $0.date < start }.map(estimate).max()
            let week = history.filter { $0.date >= start && $0.date <= end }
            guard let before, before > 0,
                  let best = week.max(by: { estimate($0) < estimate($1) }),
                  estimate(best) > before else { return nil }
            return (Record(exercise: exercise, weight: best.weight, reps: best.reps),
                    estimate(best) / before - 1)
        }
        return ranked.sorted {
            $0.gain != $1.gain ? $0.gain > $1.gain : $0.record.exercise < $1.record.exercise
        }.map(\.record)
    }
}
