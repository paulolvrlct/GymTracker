import XCTest
@testable import GymTracker

/// Séance interrompue : ce qui est sauvegardé, et ce qui est trop vieux pour être repris.
final class WorkoutDraftTests: XCTestCase {

    private let suite = "fr.devshield.gymtracker.tests.draft"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func draft(startedAt date: Date) -> WorkoutDraft {
        WorkoutDraft(
            templateName: "Séance B",
            startDate: date,
            exercises: [.init(name: "Tirage vertical poulie", catalogID: "0150", sets: 4,
                              repRange: "6-10", restSeconds: 120, notes: "")],
            sets: [.init(exerciseName: "Tirage vertical poulie", reps: 9, weight: 52.5),
                   .init(exerciseName: "Tirage vertical poulie", reps: 8, weight: 52.5)],
            timeBudget: 30)
    }

    func testSavedSessionComesBackIntact() throws {
        let original = draft(startedAt: Date(timeIntervalSince1970: 1_790_000_000))
        WorkoutDraftStore.save(original, to: defaults)
        let restored = try XCTUnwrap(WorkoutDraftStore.load(from: defaults,
                                                            now: original.startDate.addingTimeInterval(600)))
        XCTAssertEqual(restored, original, "remplacement d'exercice et séance express compris")
        XCTAssertEqual(restored.sets.count, 2)
        XCTAssertEqual(restored.timeBudget, 30)
    }

    func testForgottenSessionIsNotReopened() {
        let old = draft(startedAt: Date(timeIntervalSince1970: 1_790_000_000))
        WorkoutDraftStore.save(old, to: defaults)
        let nextDay = old.startDate.addingTimeInterval(13 * 3600)
        XCTAssertNil(WorkoutDraftStore.load(from: defaults, now: nextDay))
        XCTAssertNil(defaults.data(forKey: WorkoutDraftStore.key), "elle est effacée au passage")
    }

    func testFinishedSessionLeavesNothing() {
        WorkoutDraftStore.save(draft(startedAt: .now), to: defaults)
        WorkoutDraftStore.clear(from: defaults)
        XCTAssertNil(WorkoutDraftStore.load(from: defaults))
    }
}
