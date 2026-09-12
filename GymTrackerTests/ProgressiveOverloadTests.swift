import XCTest
@testable import GymTracker

/// Objectif du jour en séance : double progression (reps, puis charge).
final class ProgressiveOverloadTests: XCTestCase {

    private typealias P = ProgressiveOverload

    private func set(_ reps: Int, _ weight: Double) -> P.PastSet { .init(reps: reps, weight: weight) }

    func testRepRangeParsing() {
        XCTAssertEqual(P.parse("6-8"), .init(min: 6, max: 8, isTimed: false))
        XCTAssertEqual(P.parse("8–12"), .init(min: 8, max: 12, isTimed: false), "tiret long")
        XCTAssertEqual(P.parse("10"), .init(min: 10, max: 10, isTimed: false))
        XCTAssertEqual(P.parse("8 à 12"), .init(min: 8, max: 12, isTimed: false))
        XCTAssertEqual(P.parse("45-60 s"), .init(min: 45, max: 60, isTimed: true))
        XCTAssertEqual(P.parse("12-8"), .init(min: 8, max: 12, isTimed: false), "ordre inversé")
        XCTAssertEqual(P.parse("8-12 reps"), .init(min: 8, max: 12, isTimed: false), "« reps » n'est pas un chrono")
        XCTAssertNil(P.parse("max"))
    }

    func testAllSetsAtTheTopAddWeight() {
        let target = P.target(lastSession: [set(8, 80), set(8, 80), set(8, 80)],
                              range: P.parse("6-8"), increment: 2.5)
        XCTAssertEqual(target, .init(reps: 6, weight: 82.5, kind: .increaseWeight,
                                     previousWeight: 80, previousReps: 8))
    }

    func testOtherwiseOneMoreRep() {
        let range = P.parse("6-8")
        let almost = P.target(lastSession: [set(8, 80), set(8, 80), set(7, 80)], range: range, increment: 2.5)
        XCTAssertEqual(almost?.kind, .addRep)
        XCTAssertEqual(almost?.reps, 8)
        XCTAssertEqual(almost?.weight, 80)

        let midway = P.target(lastSession: [set(7, 80), set(6, 80), set(6, 80)], range: range, increment: 2.5)
        XCTAssertEqual(midway?.kind, .addRep)
        XCTAssertEqual(midway?.reps, 7)
    }

    func testBelowTheRangeConsolidates() {
        let target = P.target(lastSession: [set(5, 85), set(4, 85)], range: P.parse("6-8"), increment: 2.5)
        XCTAssertEqual(target?.kind, .consolidate)
        XCTAssertEqual(target?.reps, 6)
        XCTAssertEqual(target?.weight, 85)
    }

    func testWarmUpSetsAreIgnored() {
        let target = P.target(lastSession: [set(12, 40), set(8, 80), set(8, 80)],
                              range: P.parse("6-8"), increment: 2.5)
        XCTAssertEqual(target?.kind, .increaseWeight)
        XCTAssertEqual(target?.weight, 82.5)
    }

    func testBodyweightAndTimedSets() {
        let pullUps = P.target(lastSession: [set(10, 0), set(9, 0)], range: P.parse("6-10"), increment: 2.5)
        XCTAssertEqual(pullUps?.reps, 11)
        XCTAssertEqual(pullUps?.weight, 0)
        let plank = P.target(lastSession: [set(50, 0), set(45, 0)], range: P.parse("45-60 s"), increment: 0)
        XCTAssertEqual(plank?.reps, 55)
        XCTAssertNil(P.target(lastSession: [], range: P.parse("6-8"), increment: 2.5), "jamais fait")
    }

    func testIncrements() {
        XCTAssertEqual(P.increment(equipment: "dumbbell", weight: 22), 2)
        XCTAssertEqual(P.increment(equipment: "barbell", weight: 60), 2.5)
        XCTAssertEqual(P.increment(equipment: "dumbbell", weight: 8), 1, "petites charges")
        XCTAssertEqual(P.increment(equipment: "body weight", weight: 0), 0)
        XCTAssertEqual(P.roundToPlate(22.1 + 2), 24)
    }
}
