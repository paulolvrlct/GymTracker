import XCTest
@testable import GymTracker

/// Moteur de la forme du jour : zones, charges, récupération et séance conseillée.
final class ReadinessTests: XCTestCase {

    /// Un jeudi, 8 h.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 8))!

    private func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

    /// Les séances types de la démo.
    private func templates(lastA: Date? = nil, lastB: Date? = nil,
                           lastLegs: Date? = nil) -> [TodayPlan.TemplateInfo] {
        [.init(name: "Séance A", loads: [.chest: 13, .shoulders: 6.5, .arms: 5], lastDone: lastA),
         .init(name: "Séance B", loads: [.back: 4, .arms: 16], lastDone: lastB),
         .init(name: "Jambes", loads: [.legs: 16, .core: 2, .back: 2], lastDone: lastLegs),
         .init(name: "Abdos", loads: [.core: 12], lastDone: nil)]
    }

    private var heavyLegDay: TrainingLoad {
        TrainingLoad.workout(name: "Jambes", date: ago(14),
                             exerciseNames: Array(repeating: "Squat", count: 18)) { _ in [.legs: 1] }
    }

    // MARK: Exercices → zones

    func testGuessFromName() {
        XCTAssertEqual(MuscleMap.guess(fromName: "Relevé de jambes"), [.core: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Développé militaire"), [.shoulders: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Squat barre"), [.legs: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Leg extension"), [.legs: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Tirage vertical"), [.back: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Curl marteau haltères"), [.arms: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Dips prise serrée"), [.arms: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Chest press"), [.chest: 1])
        XCTAssertEqual(MuscleMap.guess(fromName: "Gainage planche"), [.core: 1])
        XCTAssertTrue(MuscleMap.guess(fromName: "Truc inconnu").isEmpty)
    }

    func testCatalogLoadCountsEachRegionOnce() {
        XCTAssertEqual(MuscleMap.load(target: "pectorals", secondary: ["shoulders", "triceps"]),
                       [.chest: 1, .shoulders: 0.5, .arms: 0.5])
        XCTAssertEqual(MuscleMap.load(target: "pectorals", secondary: ["upper chest"]), [.chest: 1])
    }

    // MARK: Séance conseillée

    func testEmptyHistoryRecommendsAWorkout() {
        let readiness = HybridReadiness(loads: [], now: now)
        XCTAssertEqual(readiness.score, 100)
        let plan = TodayPlan.make(readiness: readiness, templates: templates(),
                                  lastRun: nil, lastWorkout: nil, now: now)
        guard case .workout = plan.action else { return XCTFail("séance attendue : \(plan.action)") }
    }

    func testHeavyLegDayAvoidsIntervalsAndLegs() {
        let readiness = HybridReadiness(loads: [heavyLegDay], now: now)
        XCTAssertLessThan(readiness.percent(.legs), 50)
        let plan = TodayPlan.make(readiness: readiness, templates: templates(lastLegs: ago(14)),
                                  lastRun: ago(72), lastWorkout: ago(14), now: now)
        XCTAssertNotEqual(plan.action, .hardRun)
        XCTAssertNotEqual(plan.action, .workout(templateName: "Jambes"))
        XCTAssertNotEqual(plan.alternative, .hardRun)
    }

    func testEasyRunYesterdaySuggestsUpperBodyOrCore() {
        let run = TrainingLoad.run(date: ago(13), km: 10, paceSecPerKm: 330, vma: 15)
        let readiness = HybridReadiness(loads: [run], now: now)
        let plan = TodayPlan.make(readiness: readiness,
                                  templates: templates(lastA: ago(60), lastB: ago(36), lastLegs: ago(100)),
                                  lastRun: ago(13), lastWorkout: ago(36), now: now)
        XCTAssertTrue([.workout(templateName: "Séance A"), .workout(templateName: "Abdos")]
            .contains(plan.action), "\(plan.action)")
    }

    func testIntervalsCostMoreThanEasyRunning() {
        XCTAssertEqual(TrainingLoad.intensityFactor(paceSecPerKm: 225, vma: 15), 1.6)
        XCTAssertEqual(TrainingLoad.intensityFactor(paceSecPerKm: 330, vma: nil), 1)
    }

    func testNeglectedRunningGetsQualityRun() {
        let old = TrainingLoad.workout(name: "Séance B", date: ago(80), exerciseNames: ["x"]) { _ in [.arms: 1] }
        let readiness = HybridReadiness(loads: [old], now: now)
        let plan = TodayPlan.make(readiness: readiness, templates: templates(lastA: ago(100), lastB: ago(80)),
                                  lastRun: ago(150), lastWorkout: ago(80), now: now)
        XCTAssertEqual(plan.action, .hardRun)
    }

    func testPureLifterIsNotPushedToRun() {
        let old = TrainingLoad.workout(name: "Séance B", date: ago(80), exerciseNames: ["x"]) { _ in [.arms: 1] }
        let readiness = HybridReadiness(loads: [old], now: now)
        let plan = TodayPlan.make(readiness: readiness, templates: templates(lastA: ago(100), lastB: ago(80)),
                                  lastRun: nil, lastWorkout: ago(80), now: now)
        guard case .workout = plan.action else { return XCTFail("muscu attendue : \(plan.action)") }
    }

    func testSixDaysInARowForcesRest() {
        let streak = (0..<6).map { day in
            TrainingLoad.run(date: ago(Double(day) * 24 + 1), km: 3, paceSecPerKm: 360, vma: nil)
        }
        let readiness = HybridReadiness(loads: streak, now: now)
        XCTAssertEqual(readiness.consecutiveActiveDays, 6)
        let plan = TodayPlan.make(readiness: readiness, templates: templates(),
                                  lastRun: ago(1), lastWorkout: nil, now: now)
        XCTAssertEqual(plan.action, .rest)
    }

    func testExhaustedBodyForcesRest() {
        let loads = [TrainingLoad.hybridRace(date: ago(10), completedSegments: 16),
                     TrainingLoad.workout(name: "Full", date: ago(12),
                                          exerciseNames: Array(repeating: "x", count: 20)) { _ in
                         [.chest: 1, .back: 1, .shoulders: 1, .arms: 1]
                     }]
        let plan = TodayPlan.make(readiness: HybridReadiness(loads: loads, now: now), templates: templates(),
                                  lastRun: nil, lastWorkout: ago(12), now: now)
        XCTAssertEqual(plan.action, .rest)
    }

    /// La date « prêt à » annoncée tombe exactement sur le seuil de 80 %.
    func testReadyDateIsExact() throws {
        let date = try XCTUnwrap(HybridReadiness(loads: [heavyLegDay], now: now).readyDate(.legs))
        XCTAssertEqual(HybridReadiness(loads: [heavyLegDay], now: date).freshness(.legs), 0.8, accuracy: 0.001)
    }

    // MARK: Apple Santé

    func testImportedActivitiesLoadTheRightAreas() {
        let ride = TrainingLoad.imported(kind: .cycling, date: ago(14), minutes: 90)
        XCTAssertEqual(ride.loads[.cardio] ?? 0, 15, accuracy: 0.01)
        XCTAssertEqual(ride.loads[.legs] ?? 0, 10, accuracy: 0.01)
        XCTAssertLessThan(HybridReadiness(loads: [ride], now: now).percent(.cardio), 60)

        let swim = TrainingLoad.imported(kind: .swimming, date: ago(14), minutes: 60)
        XCTAssertGreaterThan(swim.loads[.shoulders] ?? 0, 5)
        XCTAssertNil(swim.loads[.legs])

        let walk = TrainingLoad.imported(kind: .walking, date: now, minutes: 30)
        XCTAssertLessThan(walk.loads[.legs] ?? 0, 1.5)
    }

    // MARK: Sommeil et variabilité cardiaque

    func testRecoverySignalsAdjustment() {
        XCTAssertEqual(RecoverySignals(sleepHours: 7.5, hrvRatio: 1.0).adjustment, 0)
        XCTAssertEqual(RecoverySignals(sleepHours: 5.5, hrvRatio: nil).adjustment, -8)
        XCTAssertEqual(RecoverySignals(sleepHours: 4.5, hrvRatio: 0.75).adjustment, -27)
        XCTAssertEqual(RecoverySignals(sleepHours: nil, hrvRatio: 1.15).adjustment, 3)
        XCTAssertEqual(RecoverySignals(sleepHours: nil, hrvRatio: nil).adjustment, 0)
    }

    /// Les signaux jouent sur la note globale, pas sur la fraîcheur des zones.
    func testSignalsMoveTheScoreNotTheAreas() {
        let tired = HybridReadiness(loads: [], now: now,
                                    signals: RecoverySignals(sleepHours: 4.5, hrvRatio: 0.75))
        XCTAssertEqual(tired.score, 73)
        XCTAssertEqual(tired.freshness(.legs), 1)
    }

    func testShortNightRulesOutIntervals() {
        let info = [TodayPlan.TemplateInfo(name: "Séance A", loads: [.chest: 12], lastDone: ago(30))]
        func plan(sleep: Double) -> TodayPlan {
            TodayPlan.make(readiness: HybridReadiness(loads: [], now: now,
                                                      signals: RecoverySignals(sleepHours: sleep, hrvRatio: nil)),
                           templates: info, lastRun: ago(150), lastWorkout: ago(30), now: now)
        }
        let shortNight = plan(sleep: 5.2)
        XCTAssertNotEqual(shortNight.action, .hardRun)
        XCTAssertNotEqual(shortNight.alternative, .hardRun)
        XCTAssertTrue(shortNight.reason.contains("5 h"), shortNight.reason)
        XCTAssertEqual(plan(sleep: 8).action, .hardRun)
    }

    // MARK: Ressenti

    func testPerceivedEffortWeighsTheLoad() {
        XCTAssertEqual(TrainingLoad.effortFactor(0), 1, "non renseigné")
        XCTAssertEqual(TrainingLoad.effortFactor(5), 1)
        XCTAssertEqual(TrainingLoad.effortFactor(10), 1.4, accuracy: 0.001)
        XCTAssertEqual(TrainingLoad.effortFactor(2), 0.76, accuracy: 0.001)

        let hard = TrainingLoad.workout(name: "A", date: now, exerciseNames: ["x"], effort: 10) { _ in [.chest: 1] }
        XCTAssertEqual(hard.loads[.chest] ?? 0, 1.4, accuracy: 0.001)
        let easyRun = TrainingLoad.run(date: now, km: 10, paceSecPerKm: 360, vma: nil, effort: 3)
        XCTAssertEqual(easyRun.loads[.cardio] ?? 0, 8.4, accuracy: 0.001)
    }

    // MARK: Muscu, course ou les deux

    /// Sans historique, la pratique choisie au premier lancement décide.
    func testFocusDecidesForNewcomers() {
        let fresh = HybridReadiness(loads: [], now: now)
        let lifter = TodayPlan.make(readiness: fresh, templates: templates(), lastRun: nil,
                                    lastWorkout: nil, now: now, focus: .lift)
        guard case .workout = lifter.action else { return XCTFail("muscu attendue : \(lifter.action)") }

        let runner = TodayPlan.make(readiness: fresh, templates: templates(), lastRun: nil,
                                    lastWorkout: nil, now: now, focus: .run)
        XCTAssertEqual(runner.action, .hardRun)
        XCTAssertNotNil(runner.alternative, "la muscu reste proposée")
    }
}
