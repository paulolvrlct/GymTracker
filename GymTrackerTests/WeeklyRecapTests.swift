import XCTest
@testable import GymTracker

/// Bilan des 7 derniers jours, pour l'image à partager.
final class WeeklyRecapTests: XCTestCase {

    private typealias S = WeeklyRecap.LoggedSet

    private let calendar = Calendar.current
    /// Dimanche 13 septembre 2026, 20 h.
    private var now: Date { date(13, 20) }

    private func date(_ day: Int, _ hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    func testRecap() {
        let recap = WeeklyRecap.make(
            workouts: [(date(8), 5200), (date(10), 6100), (date(12), 4700), (date(5), 9999)], // le 5 : hors fenêtre
            runs: [(date(9), 8.2), (date(12, 7), 10.0), (date(6), 42)],                     // le 6 : hors fenêtre
            raceDates: [date(11, 10)],
            sets: [S(exercise: "Squat", reps: 5, weight: 100, date: date(1)),
                   S(exercise: "Squat", reps: 5, weight: 105, date: date(10)),        // +5 %
                   S(exercise: "Curl", reps: 10, weight: 14, date: date(2)),
                   S(exercise: "Curl", reps: 10, weight: 16, date: date(12)),         // +14 %
                   S(exercise: "Développé", reps: 8, weight: 80, date: date(3)),
                   S(exercise: "Développé", reps: 8, weight: 77.5, date: date(12)),   // baisse
                   S(exercise: "Tractions lestées", reps: 6, weight: 10, date: date(8))], // première fois
            streakWeeks: 4, now: now, calendar: calendar)

        XCTAssertEqual(recap.start, calendar.startOfDay(for: date(7)), "lundi 7 → dimanche 13")
        XCTAssertEqual(recap.workouts, 3)
        XCTAssertEqual(recap.runs, 2)
        XCTAssertEqual(recap.races, 1)
        XCTAssertEqual(recap.kilometres, 18.2, accuracy: 0.001)
        XCTAssertEqual(recap.longestRunKm, 10)
        XCTAssertEqual(recap.tonnes, 16.0, accuracy: 0.001)
        XCTAssertEqual(recap.activeDays, 5, "le 12 ne compte qu'une fois")
        XCTAssertEqual(recap.streakWeeks, 4)
        XCTAssertFalse(recap.isEmpty)

        XCTAssertEqual(recap.personalRecords, 2, "ni la première fois ni une baisse")
        XCTAssertEqual(recap.topRecords.count, 2)
        XCTAssertEqual(recap.topRecords.first, .init(exercise: "Curl", weight: 16, reps: 10),
                       "classement par progression relative")
        XCTAssertEqual(recap.topRecords[1].exercise, "Squat")

        XCTAssertEqual(recap.days.count, 7)
        XCTAssertFalse(recap.days[0].isActive)
        XCTAssertTrue(calendar.isDate(recap.days[0].date, inSameDayAs: date(7)))
        XCTAssertTrue(recap.days[1].lifted && !recap.days[1].ran)
        XCTAssertTrue(recap.days[5].lifted && recap.days[5].ran)
        XCTAssertTrue(recap.days[4].raced && !recap.days[4].lifted)
    }

    func testEmptyWeek() {
        let recap = WeeklyRecap.make(workouts: [], runs: [], raceDates: [], sets: [], streakWeeks: 0,
                                     now: now, calendar: calendar)
        XCTAssertTrue(recap.isEmpty)
        XCTAssertEqual(recap.activeDays, 0)
        XCTAssertTrue(recap.topRecords.isEmpty)
        XCTAssertEqual(recap.days.count, 7)
    }
}
