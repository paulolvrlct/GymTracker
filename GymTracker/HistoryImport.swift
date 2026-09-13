import Foundation
import SwiftData

// MARK: - Import de l'historique d'une autre app

/// Lit l'export CSV de Strong, de Hevy ou de LiftRun, pour reprendre son
/// historique en changeant d'app.
///
/// Personne ne change d'app s'il doit repartir de zéro : des mois de charges,
/// ce sont les objectifs du jour, les records, la forme du jour et les paliers.
/// Le format se reconnaît à ses en-têtes, pas au nom du fichier.
enum HistoryImport {

    enum Source: String {
        case strong, hevy, liftRun
    }

    struct ImportedSet: Equatable {
        let exercise: String
        let reps: Int
        let weightKg: Double
    }

    struct Workout: Equatable {
        let date: Date
        let name: String
        let durationSeconds: Int
        var sets: [ImportedSet]
    }

    struct Parsed: Equatable {
        let source: Source
        /// Du plus ancien au plus récent.
        let workouts: [Workout]
        /// Lignes ignorées : échauffements, minuteurs de repos, cardio.
        let skippedRows: Int
        /// Strong n'écrit pas toujours l'unité des charges : la personne choisit.
        let needsUnitChoice: Bool

        var setCount: Int { workouts.reduce(0) { $0 + $1.sets.count } }
    }

    static let poundsToKg = 0.45359237

    // MARK: Lecture

    /// nil si le fichier n'est pas un export reconnu.
    /// - Parameter pounds: charges en livres, quand le fichier ne le dit pas.
    static func parse(_ text: String, pounds: Bool = false) -> Parsed? {
        let table = rows(text)
        guard let first = table.first else { return nil }
        let header = first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let body = table.dropFirst()
        func column(_ names: String...) -> Int? {
            names.lazy.compactMap { header.firstIndex(of: $0) }.first
        }

        // Strong
        if let exercise = column("exercise name"), let date = column("date"),
           let reps = column("reps") {
            let name = column("workout name"), duration = column("duration")
            let order = column("set order"), weight = column("weight")
            let unit = column("weight unit"), seconds = column("seconds")
            var entries: [Entry] = []
            var skipped = 0
            for row in body {
                let value = { (index: Int?) in field(row, index) }
                let setOrder = value(order).lowercased()
                guard let start = parseDate(value(date)),
                      setOrder != "rest timer", setOrder != "w" else { skipped += 1; continue }
                let inPounds = unit.map { value($0).lowercased().hasPrefix("lb") } ?? pounds
                guard let set = makeSet(exercise: value(exercise), reps: value(reps),
                                        seconds: value(seconds), weight: value(weight),
                                        pounds: inPounds) else { skipped += 1; continue }
                entries.append(Entry(date: start, name: value(name),
                                     duration: parseDuration(value(duration)), set: set))
            }
            return Parsed(source: .strong, workouts: group(entries), skippedRows: skipped,
                          needsUnitChoice: unit == nil)
        }

        // Hevy
        if let exercise = column("exercise_title"), let start = column("start_time"),
           let reps = column("reps") {
            let title = column("title"), end = column("end_time"), type = column("set_type")
            let kilos = column("weight_kg"), pounds = column("weight_lbs")
            let seconds = column("duration_seconds")
            var entries: [Entry] = []
            var skipped = 0
            for row in body {
                let value = { (index: Int?) in field(row, index) }
                guard let date = parseDate(value(start)),
                      value(type).lowercased() != "warmup" else { skipped += 1; continue }
                let weight = kilos.map { value($0) } ?? value(pounds)
                guard let set = makeSet(exercise: value(exercise), reps: value(reps),
                                        seconds: value(seconds), weight: weight,
                                        pounds: kilos == nil && pounds != nil) else {
                    skipped += 1; continue
                }
                let duration = parseDate(value(end)).map { Int($0.timeIntervalSince(date)) } ?? 0
                entries.append(Entry(date: date, name: value(title),
                                     duration: max(0, duration), set: set))
            }
            return Parsed(source: .hevy, workouts: group(entries), skippedRows: skipped,
                          needsUnitChoice: false)
        }

        // LiftRun (export CSV de l'app)
        if let exercise = column("exercice"), let date = column("date"),
           let reps = column("reps"), let weight = column("poids_kg") {
            var entries: [Entry] = []
            var skipped = 0
            let name = String(localized: "Séance importée")
            for row in body {
                guard let start = parseDate(field(row, date)),
                      let set = makeSet(exercise: field(row, exercise), reps: field(row, reps),
                                        seconds: "", weight: field(row, weight), pounds: false)
                else { skipped += 1; continue }
                entries.append(Entry(date: start, name: name, duration: 0, set: set))
            }
            return Parsed(source: .liftRun, workouts: group(entries), skippedRows: skipped,
                          needsUnitChoice: false)
        }
        return nil
    }

    private struct Entry {
        let date: Date
        let name: String
        let duration: Int
        let set: ImportedSet
    }

    /// Une série exploitable : un nom, et des répétitions (ou des secondes,
    /// pour un exercice au temps, comme dans LiftRun).
    private static func makeSet(exercise: String, reps: String, seconds: String,
                                weight: String, pounds: Bool) -> ImportedSet? {
        let name = exercise.trimmingCharacters(in: .whitespaces)
        let count = Int(number(reps) ?? 0)
        let timed = Int(number(seconds) ?? 0)
        let value = count > 0 ? count : timed
        guard !name.isEmpty, value > 0 else { return nil }
        var kilos = max(0, number(weight) ?? 0)
        if pounds { kilos = ProgressiveOverload.roundToPlate(kilos * poundsToKg) }
        return ImportedSet(exercise: name, reps: value, weightKg: kilos)
    }

    /// Regroupe les lignes en séances (même début, même nom), dans l'ordre.
    private static func group(_ entries: [Entry]) -> [Workout] {
        struct Key: Hashable { let date: Date; let name: String }
        var order: [Key] = []
        var workouts: [Key: Workout] = [:]
        for entry in entries {
            let key = Key(date: entry.date, name: entry.name)
            if workouts[key] == nil {
                order.append(key)
                workouts[key] = Workout(date: entry.date, name: entry.name,
                                        durationSeconds: entry.duration, sets: [])
            }
            workouts[key]?.sets.append(entry.set)
        }
        return order.compactMap { workouts[$0] }.sorted { $0.date < $1.date }
    }

    // MARK: Champs

    private static func field(_ row: [String], _ index: Int?) -> String {
        guard let index, row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespaces)
    }

    /// Nombre saisi avec un point ou une virgule décimale.
    static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// « 1h 5m », « 45m », « 30s », ou un nombre de secondes.
    static func parseDuration(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let seconds = Int(trimmed) { return seconds }
        var total = 0
        var digits = ""
        for character in trimmed.lowercased() {
            if character.isNumber {
                digits.append(character)
            } else if let value = Int(digits) {
                switch character {
                case "h": total += value * 3600
                case "m": total += value * 60
                case "s": total += value
                default: break
                }
                digits = ""
            }
        }
        return total
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    /// Formats de Strong (« 2026-09-01 18:02:11 »), de Hevy
    /// (« 15 Jan 2026, 18:00 ») et ISO 8601 (export LiftRun). Les exports
    /// écrivent l'heure locale.
    static func parseDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let date = ISO8601DateFormatter().date(from: trimmed) { return date }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "d MMM yyyy, HH:mm",
                       "d MMM yyyy HH:mm", "yyyy-MM-dd'T'HH:mm:ss"] {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// CSV avec guillemets et guillemets doublés ; séparateur virgule ou
    /// point-virgule (exports en langue française), détecté sur l'en-tête.
    static func rows(_ text: String) -> [[String]] {
        let content = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let headerLine = content.prefix { !$0.isNewline }
        let separator: Character = headerLine.filter { $0 == ";" }.count
            > headerLine.filter { $0 == "," }.count ? ";" : ","

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = content.makeIterator()
        var pending: Character? = nil

        while let character = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if character == "\"" {
                    let next = iterator.next()
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        pending = next
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == separator {
                row.append(field)
                field = ""
            } else if character.isNewline {
                row.append(field)
                field = ""
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
            } else {
                field.append(character)
            }
        }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }

    // MARK: Noms d'exercices

    /// Retrouve un exercice exporté dans le catalogue : « Bench Press
    /// (Barbell) » devient « barbell bench press », affiché sous son nom
    /// LiftRun. Les objectifs du jour s'appuient sur le nom : c'est ce qui relie
    /// l'historique importé aux séances types.
    struct NameMatcher {
        private let byName: [String: CatalogExercise]
        private let entries: [(words: Set<Substring>, exercise: CatalogExercise)]

        /// Matériel entre parenthèses chez Strong et Hevy → préfixe du catalogue.
        private static let equipmentPrefix: [String: String] = [
            "barbell": "barbell", "dumbbell": "dumbbell", "cable": "cable",
            "machine": "lever", "smith machine": "smith", "kettlebell": "kettlebell",
            "band": "band", "assisted": "assisted", "weighted": "weighted",
            "ez bar": "ez barbell", "bodyweight": "",
        ]

        init(catalog: [CatalogExercise]) {
            var byName: [String: CatalogExercise] = [:]
            for exercise in catalog where byName[Self.normalized(exercise.name)] == nil {
                byName[Self.normalized(exercise.name)] = exercise
            }
            self.byName = byName
            entries = catalog.map { (Set(Self.normalized($0.name).split(separator: " ")), $0) }
        }

        func match(_ imported: String) -> CatalogExercise? {
            let lower = imported.lowercased()
            var base = lower
            var equipment = ""
            if let open = lower.lastIndex(of: "("), let close = lower.lastIndex(of: ")"), open < close {
                equipment = String(lower[lower.index(after: open)..<close])
                    .trimmingCharacters(in: .whitespaces)
                base = String(lower[..<open])
            }
            let prefix = Self.equipmentPrefix[equipment] ?? equipment
            let candidates = [prefix.isEmpty ? base : prefix + " " + base, base].map(Self.normalized)
            for candidate in candidates {
                if let exercise = byName[candidate] { return exercise }
            }
            // Tous les mots présents : « cable lat pulldown » trouve « cable lat
            // pulldown full range of motion ». Le nom le plus court l'emporte :
            // c'est la variante de base.
            for candidate in candidates {
                let words = Set(candidate.split(separator: " "))
                guard words.count >= 2 else { continue }
                if let exercise = entries.filter({ words.isSubset(of: $0.words) })
                    .min(by: { $0.exercise.name.count < $1.exercise.name.count })?.exercise {
                    return exercise
                }
            }
            return nil
        }

        static func normalized(_ text: String) -> String {
            text.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .joined(separator: " ")
        }
    }

    // MARK: Enregistrement

    /// Ajoute les séances à l'historique. Une séance qui commence à la même
    /// minute qu'une séance existante est un doublon : réimporter le même
    /// fichier ne crée rien.
    @MainActor
    static func insert(_ workouts: [Workout], into context: ModelContext,
                       catalog: [CatalogExercise] = ExerciseCatalog.all) -> (added: Int, duplicates: Int) {
        func minute(_ date: Date) -> Int { Int(date.timeIntervalSince1970 / 60) }
        let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        var known = Set(existing.map { minute($0.date) })
        let matcher = NameMatcher(catalog: catalog)
        var names: [String: String] = [:]
        var added = 0
        var duplicates = 0

        for workout in workouts {
            guard known.insert(minute(workout.date)).inserted else {
                duplicates += 1
                continue
            }
            let session = WorkoutSession(date: workout.date, templateName: workout.name,
                                         durationSeconds: workout.durationSeconds)
            context.insert(session)
            var indexes: [String: Int] = [:]
            for set in workout.sets {
                let name = names[set.exercise] ?? {
                    let resolved = matcher.match(set.exercise)?.displayName ?? set.exercise
                    names[set.exercise] = resolved
                    return resolved
                }()
                indexes[name, default: 0] += 1
                let record = SetRecord(exerciseName: name, setIndex: indexes[name] ?? 1,
                                       reps: set.reps, weight: set.weightKg, date: workout.date)
                record.session = session
                context.insert(record)
            }
            added += 1
        }
        context.saveLogging()
        return (added, duplicates)
    }
}
