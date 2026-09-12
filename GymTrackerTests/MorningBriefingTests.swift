import XCTest
@testable import GymTracker

/// Point du matin : la prochaine occurrence est toujours strictement à venir.
final class MorningBriefingTests: XCTestCase {

    private var paris: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func next(after now: Date, _ hour: Int, _ minute: Int = 0) -> Date? {
        MorningBriefing.nextDate(after: now, hour: hour, minute: minute, calendar: paris)
    }

    func testLaterTodayWhenTheHourIsAhead() {
        XCTAssertEqual(next(after: date(9, 10, 7), 8), date(9, 10, 8))
        XCTAssertEqual(next(after: date(9, 10, 7), 7, 45), date(9, 10, 7, 45))
    }

    func testTomorrowOnceTheHourHasPassed() {
        XCTAssertEqual(next(after: date(9, 10, 9, 30), 8), date(9, 11, 8))
        XCTAssertEqual(next(after: date(9, 10, 8), 8), date(9, 11, 8), "strictement après")
    }

    /// Nuit du changement d'heure (25 octobre 2026) : toujours 8 h locales.
    func testDaylightSavingNight() {
        XCTAssertEqual(next(after: date(10, 24, 22), 8), date(10, 25, 8))
    }

    func testTitleCarriesScoreAndSession() {
        let title = MorningBriefing.title(score: 82, action: "Séance A")
        XCTAssertTrue(title.contains("82") && title.contains("Séance A"), title)
    }
}
