import XCTest
@testable import GymTracker

/// Régularité à la semaine : les jours de repos ne cassent rien.
final class WeeklyStreakTests: XCTestCase {

    /// Semaines du lundi au dimanche, comme en France.
    private var paris: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 18, _ minute: Int = 0) -> Date {
        paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Jeudi 10 septembre 2026, 20 h. Semaines : 24-30 août, 31 août-6 sept, 7-13 sept (en cours).
    private var now: Date { date(9, 10, 20) }
    /// Lundi et mercredi, dont un jour doublé muscu + course.
    private var thisWeek: [Date] { [date(9, 7), date(9, 9), date(9, 9, 7)] }

    private func status(_ dates: [Date], goal: Int = 3) -> WeeklyStreak.Status {
        WeeklyStreak.status(activityDates: dates, goal: goal, now: now, calendar: paris)
    }

    func testDefaults() {
        XCTAssertEqual(WeeklyStreak.defaultGoal, 3)
        XCTAssertEqual(status([]), .init(weeks: 0, thisWeek: 0, goal: 3))
    }

    func testCurrentWeek() {
        let current = status(thisWeek)
        XCTAssertEqual(current.thisWeek, 2, "un jour doublé ne compte qu'une fois")
        XCTAssertEqual(current.weeks, 0)
        XCTAssertFalse(current.isThisWeekDone)
        XCTAssertEqual(current.progress, 2.0 / 3, accuracy: 0.001)
    }

    func testUnfinishedWeekBreaksNothing() {
        let past = [date(9, 1), date(9, 3), date(9, 5), date(8, 24), date(8, 26), date(8, 29)]
        XCTAssertEqual(status(thisWeek + past).weeks, 2)

        let done = status(thisWeek + past + [date(9, 10)])
        XCTAssertEqual(done.weeks, 3)
        XCTAssertTrue(done.isThisWeekDone)
    }

    func testMissedWeekResetsTheStreak() {
        let gap = [date(9, 1), date(9, 3), date(8, 24), date(8, 26), date(8, 29)]
        XCTAssertEqual(status(thisWeek + gap).weeks, 0)
    }

    func testSundayNightBelongsToThePreviousWeek() {
        let result = WeeklyStreak.status(activityDates: [date(9, 6, 23, 30)], goal: 1,
                                         now: date(9, 7, 9), calendar: paris)
        XCTAssertEqual(result.thisWeek, 0)
        XCTAssertEqual(result.weeks, 1)
    }
}
