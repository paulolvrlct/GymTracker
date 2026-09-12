import XCTest
@testable import GymTracker

/// Simulateur de course hybride et plan de préparation de 8 semaines.
final class HybridRaceTests: XCTestCase {

    private typealias H = HybridRace

    // MARK: Format et charges

    func testRaceFormat() {
        let full = H.segments(for: .full)
        XCTAssertEqual(full.count, 16)
        XCTAssertEqual(full.first, .run(number: 1))
        XCTAssertEqual(full[1], .station(.skiErg))
        XCTAssertEqual(full[14], .run(number: 8))
        XCTAssertEqual(full.last, .station(.wallBalls))

        let half = H.segments(for: .half)
        XCTAssertEqual(half.count, 8)
        XCTAssertEqual(half.last, .station(.burpeeBroadJump))
    }

    func testDivisionLoads() {
        XCTAssertEqual(H.Station.sledPush.load(for: .openWomen), 102)
        XCTAssertEqual(H.Station.sledPush.load(for: .openMen), 152)
        XCTAssertEqual(H.Station.sledPull.load(for: .proWomen), 103)
        XCTAssertEqual(H.Station.sandbagLunges.load(for: .openWomen), 10)
        XCTAssertEqual(H.Station.wallBalls.load(for: .openMen), 6)
        XCTAssertEqual(H.Station.wallBalls.reps, 100)
        XCTAssertNil(H.Station.skiErg.load(for: .proMen))
        XCTAssertEqual(H.Station.skiErg.meters, 1000)
    }

    // MARK: Analyse

    func testAnalysis() {
        let reference = [300, 280, 310, 200, 305, 260, 300, 320]
        let current = [290, 300, 305, 180, 330, 250, 295, 330]

        XCTAssertEqual(H.deltas(splits: current, reference: reference), [-10, 20, -5, -20, 25, -10, -5, 10])
        XCTAssertTrue(H.deltas(splits: current, reference: nil).allSatisfy { $0 == nil })

        let totals = H.totals(splits: current, format: .half)
        XCTAssertEqual(totals.running, 290 + 305 + 330 + 295)
        XCTAssertEqual(totals.stations, 300 + 180 + 250 + 330)

        let loss = H.biggestLoss(splits: current, reference: reference)
        XCTAssertEqual(loss?.index, 4, "3e km")
        XCTAssertEqual(loss?.seconds, 25)
        XCTAssertNil(H.biggestLoss(splits: reference, reference: reference))

        XCTAssertEqual(H.best(of: [current, reference, [1, 2]], format: .half), reference,
                       "meilleure course complète du format")
    }

    // MARK: Plan de 8 semaines

    func testPlanStructure() {
        let plan = HybridPlan.weeks()
        XCTAssertEqual(plan.count, 8)
        XCTAssertTrue(plan.allSatisfy { $0.sessions.map(\.day) == [1, 3, 5, 7] }, "lun, mer, ven, dim")
        XCTAssertEqual(plan.map(\.phase),
                       [.base, .base, .development, .development, .specific, .specific, .specific, .taper])
        XCTAssertEqual(plan.filter { $0.sessions[3].opensRaceSimulator }.map(\.number), [3, 4, 6, 7])
        XCTAssertEqual(plan[5].sessions[3].minutes, 80, "semaine 6 : course complète")
        XCTAssertTrue(plan[7].sessions.allSatisfy { $0.minutes <= 40 }, "affûtage léger")
    }

    func testIntervalsFollowTheTenKPlan() {
        let plan = HybridPlan.weeks()
        let tenK = TrainingPlans.weeks(for: .tenK)
        for index in 0..<8 {
            XCTAssertEqual(plan[index].sessions[1].run?.intervals,
                           tenK[index].sessions.first { $0.kind == .quality }?.intervals,
                           "semaine \(index + 1)")
        }
        XCTAssertEqual(plan[0].sessions[1].run?.intervals?.effortSeconds, 30, "semaine 1 : 30/30")
    }

    /// Jamais deux séances de jambes à moins de 48 h, y compris du dimanche au lundi.
    func testLegsAlwaysGet48Hours() {
        let plan = HybridPlan.weeks()
        XCTAssertTrue(plan.allSatisfy { $0.sessions[0].kind == .upperStrength && !$0.sessions[0].loadsLegs })
        let sessions = plan.flatMap { week in
            week.sessions.map { (day: (week.number - 1) * 7 + $0.day, legs: $0.loadsLegs) }
        }
        for (previous, next) in zip(sessions, sessions.dropFirst()) where previous.legs && next.legs {
            XCTAssertGreaterThanOrEqual(next.day - previous.day, 2, "jour \(next.day)")
        }
    }
}
