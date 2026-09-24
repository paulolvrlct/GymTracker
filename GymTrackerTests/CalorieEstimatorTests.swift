import XCTest
@testable import GymTracker

/// Dépense d'une séance : le temps passé, mais aussi ce qui a été soulevé.
final class CalorieEstimatorTests: XCTestCase {

    private let hour = 3600
    private let me = 80.0

    func testDurationAlone() {
        // 3,5 METs pendant une heure pour 80 kg
        XCTAssertEqual(CalorieEstimator.workoutKcal(durationSeconds: hour, weightKg: me), 280)
        XCTAssertEqual(CalorieEstimator.workoutKcal(durationSeconds: hour / 2, weightKg: me), 140)
    }

    func testVolumeCounts() {
        // 10 tonnes soulevées ajoutent une soixantaine de kcal au travail de fond
        XCTAssertEqual(CalorieEstimator.workoutKcal(durationSeconds: hour, weightKg: me, volumeKg: 10_000), 341)
    }

    /// Le reproche d'origine : deux séances d'une heure ne peuvent pas coûter pareil.
    func testHeavierSessionBurnsMore() {
        let légère = CalorieEstimator.workoutKcal(durationSeconds: hour, weightKg: me, volumeKg: 4_000)
        let lourde = CalorieEstimator.workoutKcal(durationSeconds: hour, weightKg: me, volumeKg: 18_000)
        XCTAssertGreaterThan(lourde, légère)
        XCTAssertEqual(lourde - légère, 86, "14 tonnes d'écart")
    }

    func testBodyweightRepsCount() {
        // 100 tractions : environ deux tiers du corps déplacés à chaque répétition
        XCTAssertEqual(CalorieEstimator.workoutKcal(durationSeconds: hour, weightKg: me, bodyweightReps: 100), 312)
    }

    func testNothingWithoutDurationOrWeight() {
        XCTAssertEqual(CalorieEstimator.workoutKcal(durationSeconds: 0, weightKg: me, volumeKg: 9_000), 0)
        XCTAssertEqual(CalorieEstimator.workoutKcal(durationSeconds: hour, weightKg: 0), 0)
        XCTAssertEqual(CalorieEstimator.workoutKcal(durationSeconds: hour, weightKg: me, volumeKg: -50), 280)
    }

    func testRunningUnchanged() {
        XCTAssertEqual(CalorieEstimator.runKcal(distanceKm: 10, weightKg: me), 800)
    }
}
