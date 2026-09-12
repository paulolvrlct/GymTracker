import Foundation

// MARK: - Paliers hybrides

/// Des paliers que seule une app muscu + course peut proposer : « 10 t
/// soulevées », « premier 10 km », mais surtout « première semaine hybride ».
///
/// Calculés à la volée depuis l'historique, comme les points d'expérience :
/// rien n'est stocké, et quelqu'un qui met à jour l'app retrouve d'emblée
/// les paliers qu'il a déjà franchis, datés du jour où il l'a fait.
enum Milestone: String, CaseIterable, Identifiable {
    case firstWorkout, firstRun, hybridDay, hybridWeek, firstHybridRace,
         first5k, sub25min5k, first10k, halfMarathon,
         tonnes10, tonnes100, km100, goalWeeks4

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstWorkout:    String(localized: "milestone.firstWorkout")
        case .firstRun:        String(localized: "milestone.firstRun")
        case .hybridDay:       String(localized: "milestone.hybridDay")
        case .hybridWeek:      String(localized: "milestone.hybridWeek")
        case .firstHybridRace: String(localized: "milestone.firstHybridRace")
        case .first5k:         String(localized: "milestone.first5k")
        case .sub25min5k:      String(localized: "milestone.sub25min5k")
        case .first10k:        String(localized: "milestone.first10k")
        case .halfMarathon:    String(localized: "milestone.halfMarathon")
        case .tonnes10:        String(localized: "milestone.tonnes10")
        case .tonnes100:       String(localized: "milestone.tonnes100")
        case .km100:           String(localized: "milestone.km100")
        case .goalWeeks4:      String(localized: "milestone.goalWeeks4")
        }
    }

    var detail: String {
        switch self {
        case .firstWorkout:    String(localized: "milestone.firstWorkout.detail")
        case .firstRun:        String(localized: "milestone.firstRun.detail")
        case .hybridDay:       String(localized: "milestone.hybridDay.detail")
        case .hybridWeek:      String(localized: "milestone.hybridWeek.detail")
        case .firstHybridRace: String(localized: "milestone.firstHybridRace.detail")
        case .first5k:         String(localized: "milestone.first5k.detail")
        case .sub25min5k:      String(localized: "milestone.sub25min5k.detail")
        case .first10k:        String(localized: "milestone.first10k.detail")
        case .halfMarathon:    String(localized: "milestone.halfMarathon.detail")
        case .tonnes10:        String(localized: "milestone.tonnes10.detail")
        case .tonnes100:       String(localized: "milestone.tonnes100.detail")
        case .km100:           String(localized: "milestone.km100.detail")
        case .goalWeeks4:      String(localized: "milestone.goalWeeks4.detail")
        }
    }

    var symbol: String {
        switch self {
        case .firstWorkout:    "dumbbell.fill"
        case .firstRun:        "figure.run"
        case .hybridDay:       "bolt.fill"
        case .hybridWeek:      "bolt.circle.fill"
        case .firstHybridRace: "flag.checkered"
        case .first5k, .first10k: "figure.run.circle.fill"
        case .sub25min5k:      "stopwatch.fill"
        case .halfMarathon:    "medal.fill"
        case .tonnes10, .tonnes100: "scalemass.fill"
        case .km100:           "road.lanes"
        case .goalWeeks4:      "calendar.badge.checkmark"
        }
    }
}

struct MilestoneStatus: Identifiable, Equatable {
    let milestone: Milestone
    /// Date du franchissement, nil tant que le palier n'est pas atteint.
    let achievedOn: Date?
    /// Avancement vers le palier, entre 0 et 1.
    let progress: Double

    var id: Milestone { milestone }
    var isAchieved: Bool { achievedOn != nil }
}

enum Milestones {

    struct Run {
        let date: Date
        let km: Double
        let durationSeconds: Int
    }

    /// Allure de 5 km sous 25 min : 5 min/km.
    static let sub25Pace: Double = 300

    static func evaluate(workouts: [(date: Date, volumeKg: Double)],
                         runs: [Run],
                         raceDates: [Date],
                         weeklyStreak: Int,
                         now: Date = .now,
                         calendar: Calendar = .current) -> [MilestoneStatus] {
        let workouts = workouts.sorted { $0.date < $1.date }
        let runs = runs.sorted { $0.date < $1.date }
        let races = raceDates.sorted()

        func status(_ milestone: Milestone, _ date: Date?, _ progress: Double) -> MilestoneStatus {
            MilestoneStatus(milestone: milestone, achievedOn: date,
                            progress: date != nil ? 1 : max(0, min(1, progress)))
        }

        /// Date à laquelle un cumul franchit un seuil.
        func crossing<T>(_ items: [T], date: (T) -> Date, value: (T) -> Double,
                         threshold: Double) -> (date: Date?, total: Double) {
            var total = 0.0
            for item in items {
                total += value(item)
                if total >= threshold { return (date(item), total) }
            }
            return (nil, total)
        }

        let longest = runs.map(\.km).max() ?? 0
        func firstRun(atLeast km: Double) -> Date? { runs.first { $0.km >= km }?.date }

        // Journée hybride : une séance et une course le même jour.
        let hybridDay = workouts.compactMap { workout in
            runs.first { calendar.isDate($0.date, inSameDayAs: workout.date) }
                .map { max($0.date, workout.date) }
        }.min()

        // Semaine hybride : au moins 2 séances et 2 courses dans la même semaine.
        var hybridWeek: Date?
        var bestWeekProgress = 0.0
        let weeks = Dictionary(grouping: workouts.map { ($0.date, true) } + runs.map { ($0.date, false) }) {
            calendar.dateInterval(of: .weekOfYear, for: $0.0)?.start ?? $0.0
        }
        for start in weeks.keys.sorted() {
            let entries = weeks[start] ?? []
            let lifts = entries.filter(\.1).map(\.0).sorted()
            let outings = entries.filter { !$0.1 }.map(\.0).sorted()
            bestWeekProgress = max(bestWeekProgress,
                                   (Double(min(lifts.count, 2)) + Double(min(outings.count, 2))) / 4)
            if lifts.count >= 2, outings.count >= 2 {
                hybridWeek = max(lifts[1], outings[1])
                break
            }
        }

        // 5 km sous 25 min : une course d'au moins 5 km à 5 min/km ou mieux.
        let fastRuns = runs.filter { $0.km >= 5 && $0.durationSeconds > 0 }
        let sub25 = fastRuns.first { Double($0.durationSeconds) / $0.km <= sub25Pace }?.date
        let bestPace = fastRuns.map { Double($0.durationSeconds) / $0.km }.min()

        let tonnes10 = crossing(workouts, date: \.date, value: { $0.volumeKg }, threshold: 10_000)
        let tonnes100 = crossing(workouts, date: \.date, value: { $0.volumeKg }, threshold: 100_000)
        let km100 = crossing(runs, date: \.date, value: \.km, threshold: 100)

        return [
            status(.firstWorkout, workouts.first?.date, 0),
            status(.firstRun, runs.first?.date, 0),
            status(.hybridDay, hybridDay, 0),
            status(.hybridWeek, hybridWeek, bestWeekProgress),
            status(.firstHybridRace, races.first, 0),
            status(.first5k, firstRun(atLeast: 5), longest / 5),
            status(.sub25min5k, sub25, bestPace.map { sub25Pace / $0 } ?? 0),
            status(.first10k, firstRun(atLeast: 10), longest / 10),
            status(.halfMarathon, firstRun(atLeast: 21.0975), longest / 21.0975),
            status(.tonnes10, tonnes10.date, tonnes10.total / 10_000),
            status(.tonnes100, tonnes100.date, tonnes100.total / 100_000),
            status(.km100, km100.date, km100.total / 100),
            status(.goalWeeks4, weeklyStreak >= 4 ? now : nil, Double(weeklyStreak) / 4),
        ]
    }
}
