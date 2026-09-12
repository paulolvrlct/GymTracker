import XCTest
@testable import GymTracker

/// Paliers hybrides : dates d'obtention et progression vers les suivants.
final class MilestonesTests: XCTestCase {

    private typealias R = Milestones.Run

    private var paris: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 18) -> Date {
        paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func find(_ list: [MilestoneStatus], _ milestone: Milestone) -> MilestoneStatus {
        list.first { $0.milestone == milestone }!
    }

    /// Août : 4 séances de 3 t, puis des courses de plus en plus longues.
    func testAugust() {
        let workouts: [(date: Date, volumeKg: Double)] = [(date(8, 3), 3000), (date(8, 5), 3000),
                                                         (date(8, 10), 3000), (date(8, 12), 3000)]
        let runs = [R(date: date(8, 4), km: 5.2, durationSeconds: 1690),
                    R(date: date(8, 10, 7), km: 8, durationSeconds: 2640),   // même jour qu'une séance
                    R(date: date(8, 13), km: 10.1, durationSeconds: 3000),   // 4'57/km : sub-25 aussi
                    R(date: date(8, 20), km: 12, durationSeconds: 4000)]
        let list = Milestones.evaluate(workouts: workouts, runs: runs, raceDates: [], weeklyStreak: 2,
                                       now: date(8, 25), calendar: paris)

        XCTAssertEqual(list.count, Milestone.allCases.count)
        XCTAssertEqual(find(list, .firstWorkout).achievedOn, date(8, 3))
        XCTAssertEqual(find(list, .firstRun).achievedOn, date(8, 4))
        XCTAssertEqual(find(list, .first5k).achievedOn, date(8, 4))
        XCTAssertEqual(find(list, .first10k).achievedOn, date(8, 13))
        XCTAssertEqual(find(list, .sub25min5k).achievedOn, date(8, 13))
        XCTAssertEqual(find(list, .hybridDay).achievedOn, date(8, 10), "séance à 18 h après la course de 7 h")
        XCTAssertEqual(find(list, .hybridWeek).achievedOn, date(8, 13))
        XCTAssertEqual(find(list, .tonnes10).achievedOn, date(8, 12), "12 t à la 4e séance")

        XCTAssertFalse(find(list, .tonnes100).isAchieved)
        XCTAssertEqual(find(list, .tonnes100).progress, 0.12, accuracy: 0.001)
        XCTAssertEqual(find(list, .halfMarathon).progress, 12 / 21.0975, accuracy: 0.001)
        XCTAssertEqual(find(list, .km100).progress, 0.353, accuracy: 0.001)
        XCTAssertFalse(find(list, .firstHybridRace).isAchieved)
        XCTAssertFalse(find(list, .goalWeeks4).isAchieved)
        XCTAssertEqual(find(list, .goalWeeks4).progress, 0.5)
    }

    func testNothingDoneYet() {
        let list = Milestones.evaluate(workouts: [], runs: [], raceDates: [], weeklyStreak: 0,
                                       now: date(8, 25), calendar: paris)
        XCTAssertTrue(list.allSatisfy { !$0.isAchieved && $0.progress == 0 })
    }

    func testSlowFiveKAndHybridRace() {
        let list = Milestones.evaluate(workouts: [], runs: [R(date: date(8, 1), km: 5, durationSeconds: 1800)],
                                       raceDates: [date(8, 2)], weeklyStreak: 4,
                                       now: date(8, 25), calendar: paris)
        XCTAssertFalse(find(list, .sub25min5k).isAchieved)
        XCTAssertEqual(find(list, .sub25min5k).progress, 300.0 / 360, accuracy: 0.001, "83 % de l'allure visée")
        XCTAssertEqual(find(list, .firstHybridRace).achievedOn, date(8, 2))
        XCTAssertTrue(find(list, .goalWeeks4).isAchieved)
    }
}
