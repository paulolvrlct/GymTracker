import XCTest
@testable import GymTracker

/// Échauffement, séance express, reprise, semaine allégée et remplacement d'exercice.
final class WorkoutCoachingTests: XCTestCase {

    private typealias Step = WarmUp.Step
    private typealias P = ProgressiveOverload

    private var paris: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 18) -> Date {
        paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    // MARK: Échauffement

    func testBarbellWarmUpClimbsToTheWorkingWeight() {
        XCTAssertEqual(WarmUp.steps(workingWeight: 82.5, equipment: "barbell"),
                       [Step(reps: 10, weight: 20), Step(reps: 8, weight: 40),
                        Step(reps: 5, weight: 57.5), Step(reps: 3, weight: 70)])
    }

    func testDumbbellAndMachineWarmUps() {
        XCTAssertEqual(WarmUp.steps(workingWeight: 24, equipment: "dumbbell"),
                       [Step(reps: 10, weight: 12), Step(reps: 5, weight: 18)])
        XCTAssertEqual(WarmUp.steps(workingWeight: 45, equipment: "leverage machine"),
                       [Step(reps: 10, weight: 22.5), Step(reps: 5, weight: 32.5)])
    }

    func testNoWarmUpForLightOrBodyweightWork() {
        XCTAssertTrue(WarmUp.steps(workingWeight: 30, equipment: "barbell").isEmpty)
        XCTAssertTrue(WarmUp.steps(workingWeight: 10, equipment: "dumbbell").isEmpty)
        XCTAssertTrue(WarmUp.steps(workingWeight: 20, equipment: "body weight").isEmpty)
    }

    // MARK: Séance express

    /// La séance B de démo : 43 minutes estimées.
    private let backAndArms: [QuickSession.Item] = [
        .init(name: "Tractions", sets: 4, restSeconds: 120),
        .init(name: "Curl EZ", sets: 3, restSeconds: 90),
        .init(name: "Curl marteau", sets: 3, restSeconds: 75),
        .init(name: "Dips", sets: 3, restSeconds: 90),
        .init(name: "Extensions poulie", sets: 3, restSeconds: 60),
    ]

    func testEstimate() {
        XCTAssertEqual(QuickSession.estimatedSeconds(backAndArms), 2605)
        XCTAssertEqual(QuickSession.estimatedSeconds([]), 0)
    }

    func testThirtyMinutesKeepsEveryExercise() {
        let fitted = QuickSession.fit(backAndArms, minutes: 30)
        XCTAssertEqual(fitted.kept.map(\.sets), [3, 3, 2, 2, 2])
        XCTAssertTrue(fitted.kept.allSatisfy { $0.restSeconds == 60 })
        XCTAssertTrue(fitted.dropped.isEmpty)
        XCTAssertLessThanOrEqual(QuickSession.estimatedSeconds(fitted.kept), 30 * 60)
    }

    func testTwentyMinutesDropsTheLastExercises() {
        let fitted = QuickSession.fit(backAndArms, minutes: 20)
        XCTAssertEqual(fitted.kept.map(\.name), ["Tractions", "Curl EZ", "Curl marteau"])
        XCTAssertEqual(fitted.dropped, ["Dips", "Extensions poulie"])
        XCTAssertLessThanOrEqual(QuickSession.estimatedSeconds(fitted.kept), 20 * 60)
    }

    func testShortSessionIsLeftAlone() {
        XCTAssertEqual(QuickSession.fit(backAndArms, minutes: 90).kept, backAndArms)
    }

    // MARK: Reprise

    func testComebackFactor() {
        XCTAssertNil(Comeback.factor(daysOff: 5))
        XCTAssertNil(Comeback.factor(daysOff: 9))
        XCTAssertEqual(Comeback.factor(daysOff: 10), 0.9)
        XCTAssertEqual(Comeback.factor(daysOff: 25), 0.85)
        XCTAssertEqual(Comeback.factor(daysOff: 60), 0.8)
    }

    func testLighterTargets() {
        let bench = P.lighter(lastSession: [.init(reps: 8, weight: 80), .init(reps: 7, weight: 80)],
                              range: P.parse("6-8"), increment: 2.5, factor: 0.9, kind: .comeback)
        XCTAssertEqual(bench, P.Target(reps: 6, weight: 70, kind: .comeback,
                                       previousWeight: 80, previousReps: 8))

        let pullUps = P.lighter(lastSession: [.init(reps: 10, weight: 0)], range: P.parse("6-10"),
                                increment: 0, factor: 0.9, kind: .deload)
        XCTAssertEqual(pullUps?.reps, 9)
        XCTAssertEqual(pullUps?.weight, 0)

        let curl = P.lighter(lastSession: [.init(reps: 10, weight: 22)], range: P.parse("8-12"),
                             increment: 2, factor: 0.85, kind: .comeback)
        XCTAssertEqual(curl?.weight, 18, "arrondi vers le bas au cran des haltères")

        XCTAssertNil(P.lighter(lastSession: [], range: nil, increment: 2.5, factor: 0.9, kind: .deload))
    }

    // MARK: Semaine allégée

    func testDeloadHalvesTheSets() {
        XCTAssertEqual(Deload.sets(4), 2)
        XCTAssertEqual(Deload.sets(3), 2)
        XCTAssertEqual(Deload.sets(1), 1)
    }

    func testSummaryKeepsTheBestEstimatedMax() {
        let summary = Deload.summary(date: date(9, 1),
                                     sets: [("Squat", 5, 100), ("Squat", 8, 90), ("Tractions", 10, 0)])
        XCTAssertEqual(summary.best["Squat"] ?? 0, 116.67, accuracy: 0.01)
        XCTAssertNil(summary.best["Tractions"], "poids du corps : pas de 1RM estimé")
    }

    func testLongBlockCallsForADeload() {
        // Lundis et jeudis, du 3 août au 3 septembre : cinq semaines pleines.
        let days = [(8, 3), (8, 6), (8, 10), (8, 13), (8, 17), (8, 20),
                    (8, 24), (8, 27), (8, 31), (9, 3)]
        let sessions = days.enumerated().map { index, day in
            Deload.Session(date: date(day.0, day.1), best: ["Squat": 100 + Double(index)])
        }
        let now = date(9, 10, 20)
        XCTAssertEqual(Deload.advice(sessions: sessions, lastDeload: nil, now: now, calendar: paris),
                       .longBlock(weeks: 5))
        XCTAssertNil(Deload.advice(sessions: Array(sessions.dropFirst(2)), lastDeload: nil,
                                   now: now, calendar: paris), "quatre semaines seulement")
        XCTAssertNil(Deload.advice(sessions: sessions, lastDeload: date(8, 20), now: now, calendar: paris),
                     "semaine allégée il y a trois semaines")
    }

    func testPlateauCallsForADeload() {
        let days = [(8, 24), (8, 26), (8, 28), (8, 31), (9, 2), (9, 4), (9, 7), (9, 9)]
        let flat = days.map {
            Deload.Session(date: date($0.0, $0.1), best: ["Squat": 120, "Développé": 90, "Rowing": 80])
        }
        XCTAssertEqual(Deload.advice(sessions: flat, lastDeload: nil, now: date(9, 10, 20), calendar: paris),
                       .plateau(exercises: 3))

        let rising = days.enumerated().map { index, day in
            Deload.Session(date: date(day.0, day.1), best: ["Squat": 120 + Double(index)])
        }
        XCTAssertNil(Deload.advice(sessions: rising, lastDeload: nil, now: date(9, 10, 20), calendar: paris))
    }

    // MARK: Remplacer un exercice

    private func exercise(_ id: String, _ name: String, _ equipment: String, _ target: String,
                          _ secondary: [String] = [], category: String = "chest") -> CatalogExercise {
        CatalogExercise(id: id, name: name, category: category, equipment: equipment,
                        target: target, secondary: secondary, steps: [])
    }

    private var catalog: [CatalogExercise] {
        [exercise("t1", "barbell bench press", "barbell", "pectorals", ["triceps", "shoulders"]),
         exercise("t2", "dumbbell bench press", "dumbbell", "pectorals", ["triceps", "shoulders"]),
         exercise("t3", "lever chest press", "leverage machine", "pectorals", ["triceps"]),
         exercise("t4", "stability ball fly", "stability ball", "pectorals"),
         exercise("t5", "barbell full squat", "barbell", "glutes", ["quadriceps"], category: "upper legs")]
    }

    func testSwapKeepsTheMuscleAndPrefersAnotherMachine() {
        let alternatives = ExerciseSwap.alternatives(to: catalog[0], named: "Développé couché", in: catalog)
        XCTAssertEqual(alternatives.map(\.id), ["t2", "t3", "t4"])
    }

    func testSwapFallsBackOnTheNameForCustomExercises() {
        XCTAssertEqual(ExerciseSwap.alternatives(to: nil, named: "Squat sauté", in: catalog).map(\.id), ["t5"])
        XCTAssertTrue(ExerciseSwap.alternatives(to: nil, named: "Truc inconnu", in: catalog).isEmpty)
    }
}
