import XCTest
import SwiftData
@testable import GymTracker

/// Import des exports CSV de Strong, de Hevy et de LiftRun.
final class HistoryImportTests: XCTestCase {

    private typealias S = HistoryImport.ImportedSet

    private let strong = """
    Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
    2026-09-01 18:02:11,"Push, lourd",1h 5m,Bench Press (Barbell),W,40,10,0,0,,,
    2026-09-01 18:02:11,"Push, lourd",1h 5m,Bench Press (Barbell),1,80,8,0,0,,,
    2026-09-01 18:02:11,"Push, lourd",1h 5m,Bench Press (Barbell),2,80,7,0,0,,,
    2026-09-01 18:02:11,"Push, lourd",1h 5m,Plank,1,0,0,0,60,,,
    2026-09-01 18:02:11,"Push, lourd",1h 5m,Bench Press (Barbell),Rest Timer,0,0,0,120,,,
    2026-09-03 07:30:00,Legs,45m,Squat (Barbell),1,100,5,0,0,,,
    """

    private let hevy = """
    "title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
    "Upper A","15 Jan 2026, 18:00","15 Jan 2026, 19:10","","Bench Press (Barbell)","","","0","warmup","40","10","","",""
    "Upper A","15 Jan 2026, 18:00","15 Jan 2026, 19:10","","Bench Press (Barbell)","","","1","normal","82,5","6","","","8"
    "Upper A","15 Jan 2026, 18:00","15 Jan 2026, 19:10","","Pull Up","","","0","normal","","10","","",""
    """

    private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day,
                                                   hour: hour, minute: minute, second: second))!
    }

    // MARK: Formats

    func testStrongExport() throws {
        let parsed = try XCTUnwrap(HistoryImport.parse(strong))
        XCTAssertEqual(parsed.source, .strong)
        XCTAssertEqual(parsed.workouts.count, 2)
        XCTAssertEqual(parsed.skippedRows, 2, "échauffement et minuteur de repos")
        XCTAssertTrue(parsed.needsUnitChoice)
        XCTAssertEqual(parsed.setCount, 4)

        let push = parsed.workouts[0]
        XCTAssertEqual(push.name, "Push, lourd")
        XCTAssertEqual(push.date, local(2026, 9, 1, 18, 2, 11))
        XCTAssertEqual(push.durationSeconds, 3900)
        XCTAssertEqual(push.sets, [S(exercise: "Bench Press (Barbell)", reps: 8, weightKg: 80),
                                   S(exercise: "Bench Press (Barbell)", reps: 7, weightKg: 80),
                                   S(exercise: "Plank", reps: 60, weightKg: 0)])
        XCTAssertEqual(parsed.workouts[1].durationSeconds, 2700)
    }

    func testPoundsAreConverted() {
        XCTAssertEqual(HistoryImport.parse(strong, pounds: true)?.workouts[0].sets[0].weightKg, 36.25)
    }

    func testHevyExport() throws {
        let parsed = try XCTUnwrap(HistoryImport.parse(hevy))
        XCTAssertEqual(parsed.source, .hevy)
        XCTAssertFalse(parsed.needsUnitChoice)
        XCTAssertEqual(parsed.skippedRows, 1)
        let workout = try XCTUnwrap(parsed.workouts.first)
        XCTAssertEqual(workout.name, "Upper A")
        XCTAssertEqual(workout.date, local(2026, 1, 15, 18, 0))
        XCTAssertEqual(workout.durationSeconds, 4200)
        XCTAssertEqual(workout.sets, [S(exercise: "Bench Press (Barbell)", reps: 6, weightKg: 82.5),
                                      S(exercise: "Pull Up", reps: 10, weightKg: 0)])
    }

    func testSemicolonsAndDecimalCommas() throws {
        let text = """
        Date;Workout Name;Duration;Exercise Name;Set Order;Weight;Reps
        2026-09-01 18:02:11;Push;1h;Bench Press (Barbell);1;82,5;8
        """
        let set = try XCTUnwrap(HistoryImport.parse(text)?.workouts.first?.sets.first)
        XCTAssertEqual(set, S(exercise: "Bench Press (Barbell)", reps: 8, weightKg: 82.5))
    }

    func testLiftRunExport() throws {
        let text = "date,exercice,serie,reps,poids_kg\n2026-09-01T16:00:00Z,Squat,1,5,100\n2026-09-01T16:00:00Z,Squat,2,5,100"
        let parsed = try XCTUnwrap(HistoryImport.parse(text))
        XCTAssertEqual(parsed.source, .liftRun)
        XCTAssertEqual(parsed.workouts.count, 1)
        XCTAssertEqual(parsed.workouts[0].sets.count, 2)
        XCTAssertEqual(parsed.workouts[0].name, String(localized: "Séance importée"))
    }

    func testUnknownFilesAreRejected() {
        XCTAssertNil(HistoryImport.parse("a,b,c\n1,2,3"))
        XCTAssertNil(HistoryImport.parse(""))
    }

    func testDurationsAndQuotes() {
        XCTAssertEqual(HistoryImport.parseDuration("1h 5m"), 3900)
        XCTAssertEqual(HistoryImport.parseDuration("45m"), 2700)
        XCTAssertEqual(HistoryImport.parseDuration("90"), 90)
        XCTAssertEqual(HistoryImport.parseDuration(""), 0)
        XCTAssertEqual(HistoryImport.rows("a,\"b,\"\"c\"\"\",d\r\n1,2,3"),
                       [["a", "b,\"c\"", "d"], ["1", "2", "3"]])
    }

    // MARK: Noms d'exercices

    private func exercise(_ id: String, _ name: String) -> CatalogExercise {
        CatalogExercise(id: id, name: name, category: "chest", equipment: "barbell",
                        target: "pectorals", secondary: [], steps: [])
    }

    func testNamesAreMatchedToTheCatalog() {
        let matcher = HistoryImport.NameMatcher(catalog: [
            exercise("t1", "barbell bench press"),
            exercise("t6", "cable lat pulldown full range of motion"),
            exercise("t5", "barbell full squat"),
            exercise("t7", "barbell bench squat"),
            exercise("t8", "pull-up"),
        ])
        XCTAssertEqual(matcher.match("Bench Press (Barbell)")?.id, "t1")
        XCTAssertEqual(matcher.match("Lat Pulldown (Cable)")?.id, "t6")
        XCTAssertEqual(matcher.match("Squat (Barbell)")?.id, "t5", "la variante la plus courte")
        XCTAssertEqual(matcher.match("Pull Up")?.id, "t8")
        XCTAssertNil(matcher.match("Zercher Walk"))
    }

    // MARK: Enregistrement

    @MainActor
    func testInsertSkipsDuplicates() throws {
        let container = try ModelContainer(for: SharedStore.schema,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let parsed = try XCTUnwrap(HistoryImport.parse(strong))
        let catalog = [exercise("t1", "barbell bench press")]

        let first = HistoryImport.insert(parsed.workouts, into: context, catalog: catalog)
        XCTAssertEqual(first.added, 2)
        XCTAssertEqual(first.duplicates, 0)

        let records = try context.fetch(FetchDescriptor<SetRecord>())
        XCTAssertEqual(records.count, 4)
        XCTAssertEqual(Set(records.map(\.exerciseName)), ["Barbell Bench Press", "Plank", "Squat (Barbell)"])
        XCTAssertEqual(records.filter { $0.exerciseName == "Barbell Bench Press" }.map(\.setIndex).sorted(), [1, 2])

        let again = HistoryImport.insert(parsed.workouts, into: context, catalog: catalog)
        XCTAssertEqual(again.added, 0)
        XCTAssertEqual(again.duplicates, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 2)
    }
}
