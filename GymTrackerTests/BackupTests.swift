import XCTest
import SwiftData
@testable import GymTracker

/// Sauvegarde complète : aller-retour fidèle, restauration qui remplace tout.
@MainActor
final class BackupTests: XCTestCase {

    private let sourceSuite = "fr.devshield.gymtracker.tests.backup-source"
    private let targetSuite = "fr.devshield.gymtracker.tests.backup-target"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: sourceSuite)
        UserDefaults().removePersistentDomain(forName: targetSuite)
        super.tearDown()
    }

    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(for: SharedStore.schema,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testRoundTripReplacesEverything() throws {
        // Données de départ
        let sourceContainer = try memoryContainer()
        let source = sourceContainer.mainContext
        let template = WorkoutTemplate(name: "Push", subtitle: "Pecs", icon: "dumbbell.fill", order: 0)
        template.exercises = [ExerciseTemplate(name: "Développé couché", targetSets: 4, repRange: "6-8",
                                               restSeconds: 120, order: 0, catalogID: "0025")]
        source.insert(template)
        let session = WorkoutSession(date: Date(timeIntervalSince1970: 1_788_000_000),
                                     templateName: "Push", durationSeconds: 3000)
        session.perceivedEffort = 7
        source.insert(session)
        let set = SetRecord(exerciseName: "Développé couché", setIndex: 1, reps: 8, weight: 80,
                            date: session.date)
        set.session = session
        source.insert(set)
        source.insert(RunSession(date: Date(timeIntervalSince1970: 1_788_100_000), distanceMeters: 10_000,
                                 durationSeconds: 3000, routeEncoded: "48.8,2.3;48.9,2.4"))
        try source.save()

        let defaults = try XCTUnwrap(UserDefaults(suiteName: sourceSuite))
        defaults.set("Paul", forKey: "profileName")
        defaults.set(true, forKey: "soundsEnabled")
        defaults.set(72.5, forKey: "profileWeightKg")
        defaults.set(7, forKey: "reminderHour")
        defaults.set(true, forKey: "debugTab")

        // Aller-retour par le fichier
        let backup = BackupManager.make(context: source, defaults: defaults, domain: sourceSuite,
                                        now: Date(timeIntervalSince1970: 1_788_200_000))
        let decoded = try BackupManager.decode(BackupManager.encode(backup))
        XCTAssertEqual(decoded, backup)
        XCTAssertEqual(decoded.settings["profileName"], .string("Paul"))
        XCTAssertEqual(decoded.settings["soundsEnabled"], .bool(true))
        XCTAssertEqual(decoded.settings["profileWeightKg"], .double(72.5))
        XCTAssertEqual(decoded.settings["reminderHour"], .int(7))
        XCTAssertNil(decoded.settings["debugTab"], "réglages de développement exclus")

        // Restauration dans une base qui a déjà ses propres données
        let targetContainer = try memoryContainer()
        let target = targetContainer.mainContext
        target.insert(WorkoutSession(date: .now, templateName: "À remplacer"))
        try target.save()
        let restoredDefaults = try XCTUnwrap(UserDefaults(suiteName: targetSuite))
        try BackupManager.restore(decoded, into: target, defaults: restoredDefaults)

        let sessions = try target.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.map(\.templateName), ["Push"])
        XCTAssertEqual(sessions.first?.perceivedEffort, 7)
        XCTAssertEqual(sessions.first?.sets.first?.weight, 80)
        XCTAssertEqual(try target.fetch(FetchDescriptor<WorkoutTemplate>()).first?.exercises.first?.catalogID, "0025")
        XCTAssertEqual(try target.fetch(FetchDescriptor<RunSession>()).first?.routeEncoded, "48.8,2.3;48.9,2.4")
        XCTAssertEqual(restoredDefaults.string(forKey: "profileName"), "Paul")
        XCTAssertEqual(restoredDefaults.double(forKey: "profileWeightKg"), 72.5)
        XCTAssertEqual(restoredDefaults.integer(forKey: "reminderHour"), 7)
        XCTAssertTrue(restoredDefaults.bool(forKey: "soundsEnabled"))
    }

    func testNewerBackupsAreRefused() throws {
        let container = try memoryContainer()
        var backup = BackupManager.make(context: container.mainContext, domain: nil)
        backup.version = LiftRunBackup.currentVersion + 1
        XCTAssertThrowsError(try BackupManager.decode(BackupManager.encode(backup)))
    }
}
