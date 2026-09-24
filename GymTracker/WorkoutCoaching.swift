import Foundation

// MARK: - Échauffement

/// Séries de chauffe avant la première série lourde d'un exercice.
///
/// Montée classique en pourcentage de la charge de travail : assez pour
/// préparer articulations et système nerveux, trop peu pour fatiguer. Rien
/// pour les charges légères ou au poids du corps, où la première série sert
/// d'échauffement.
enum WarmUp {

    struct Step: Equatable {
        let reps: Int
        let weight: Double
    }

    static func steps(workingWeight: Double, equipment: String?) -> [Step] {
        switch equipment {
        case "body weight", "band", "resistance band", "assisted", "weighted",
             "stability ball", "bosu ball", "medicine ball", "roller", "wheel roller":
            return []
        case "barbell", "olympic barbell", "trap bar", "smith machine", "ez barbell":
            let bar: Double = equipment == "ez barbell" ? 10 : 20
            guard workingWeight >= bar * 2 else { return [] }
            return ladder(workingWeight, start: Step(reps: 10, weight: bar),
                          [(0.5, 8), (0.7, 5), (0.85, 3)], step: 2.5)
        case "dumbbell", "kettlebell":
            guard workingWeight >= 12 else { return [] }
            return ladder(workingWeight, start: nil, [(0.5, 10), (0.75, 5)], step: 2)
        default:
            guard workingWeight >= 20 else { return [] }
            return ladder(workingWeight, start: nil, [(0.5, 10), (0.75, 5)], step: 2.5)
        }
    }

    /// Paliers arrondis vers le bas (un échauffement un peu trop léger ne
    /// coûte rien, un peu trop lourd si), toujours croissants et sous la
    /// charge de travail.
    private static func ladder(_ working: Double, start: Step?, _ ratios: [(Double, Int)],
                               step: Double) -> [Step] {
        var result = start.map { [$0] } ?? []
        for (ratio, reps) in ratios {
            let weight = (working * ratio / step).rounded(.down) * step
            guard weight > (result.last?.weight ?? 0), weight < working else { continue }
            result.append(Step(reps: reps, weight: weight))
        }
        return result
    }
}

// MARK: - Séance express

/// « J'ai 30 minutes » : la séance du jour condensée pour tenir dans le temps
/// disponible.
///
/// On taille d'abord dans ce qui coûte le moins : les repos, puis les séries
/// des exercices d'isolation. Les derniers exercices ne sautent qu'en dernier
/// recours — les exercices principaux, en tête de séance, restent.
enum QuickSession {

    struct Item: Equatable {
        let name: String
        var sets: Int
        var restSeconds: Int
    }

    /// Effort moyen d'une série, et installation d'un exercice (réglages,
    /// chargement, première série d'approche).
    static let secondsPerSet = 40
    static let setupPerExercise = 120

    static func estimatedSeconds(_ items: [Item]) -> Int {
        guard let last = items.last else { return 0 }
        let total = items.reduce(0) {
            $0 + $1.sets * (secondsPerSet + $1.restSeconds) + setupPerExercise
        }
        // Pas de repos après la toute dernière série.
        return total - last.restSeconds
    }

    static func fit(_ items: [Item], minutes: Int) -> (kept: [Item], dropped: [String]) {
        let budget = minutes * 60
        var kept = items
        var dropped: [String] = []
        func fits() -> Bool { estimatedSeconds(kept) <= budget }

        let cuts: [(inout [Item]) -> Void] = [
            // 1. Repos plafonnés à 90 s, 3 séries au plus.
            { items in
                for i in items.indices {
                    items[i].restSeconds = min(items[i].restSeconds, 90)
                    items[i].sets = min(items[i].sets, 3)
                }
            },
            // 2. Deux séries pour tout ce qui suit les deux premiers exercices.
            { items in
                for i in items.indices where i >= 2 { items[i].sets = min(items[i].sets, 2) }
            },
            // 3. Repos à 60 s.
            { items in
                for i in items.indices { items[i].restSeconds = min(items[i].restSeconds, 60) }
            },
        ]
        for cut in cuts where !fits() { cut(&kept) }
        // 4. Les derniers exercices sautent, jamais les deux premiers.
        while !fits(), kept.count > 2 {
            dropped.insert(kept.removeLast().name, at: 0)
        }
        // 5. Toujours trop long : deux séries partout.
        if !fits() {
            for i in kept.indices { kept[i].sets = min(kept[i].sets, 2) }
        }
        return (kept, dropped)
    }
}

// MARK: - Reprise après une pause

/// Après dix jours sans séance, la première reprend à une charge réduite.
///
/// La force revient en quelques séances ; tendons et articulations, eux, ont
/// besoin d'une semaine. C'est aussi le moment où la plupart des gens lâchent :
/// une première séance ratée à l'ancienne charge décourage plus qu'une pause.
enum Comeback {
    static let minimumDaysOff = 10

    /// Part de la charge habituelle, selon la durée de la pause.
    static func factor(daysOff: Int) -> Double? {
        switch daysOff {
        case ..<minimumDaysOff: nil
        case ..<21: 0.9
        case ..<42: 0.85
        default: 0.8
        }
    }
}

// MARK: - Semaine allégée

/// Une semaine plus légère après un long bloc ou quand la progression cale :
/// ce que ferait un coach, et ce que personne ne pense à faire seul.
enum Deload {

    enum Reason: Equatable {
        /// Semaines d'entraînement d'affilée, sans semaine allégée.
        case longBlock(weeks: Int)
        /// Exercices qui ne progressent plus.
        case plateau(exercises: Int)
    }

    static let blockWeeks = 5
    static let lengthDays = 7
    /// Charges de la semaine allégée, en part de la charge habituelle.
    static let weightFactor = 0.9

    /// Une séance résumée : meilleur 1RM estimé de chaque exercice lesté.
    struct Session: Equatable {
        let date: Date
        let best: [String: Double]
    }

    static func summary(date: Date, sets: [(exercise: String, reps: Int, weight: Double)]) -> Session {
        var best: [String: Double] = [:]
        for set in sets where set.weight > 0 {
            best[set.exercise] = max(best[set.exercise] ?? 0, estimated1RM(weight: set.weight, reps: set.reps))
        }
        return Session(date: date, best: best)
    }

    /// Formule d'Epley.
    static func estimated1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30)
    }

    /// Moitié des séries, arrondie au-dessus.
    static func sets(_ planned: Int) -> Int {
        max(1, (planned + 1) / 2)
    }

    static func advice(sessions: [Session], lastDeload: Date?, now: Date,
                       calendar: Calendar = .current) -> Reason? {
        // Une semaine allégée récente : rien à proposer avant un nouveau bloc.
        if let lastDeload, now.timeIntervalSince(lastDeload) < Double(blockWeeks * 7) * 86_400 {
            return nil
        }
        let since = lastDeload ?? .distantPast
        let relevant = sessions.filter { $0.date > since && $0.date <= now }
        let stalled = stalledExercises(relevant, now: now)
        if stalled >= 3 { return .plateau(exercises: stalled) }
        let weeks = trainingWeeks(relevant.map(\.date), now: now, calendar: calendar)
        if weeks >= blockWeeks { return .longBlock(weeks: weeks) }
        return nil
    }

    /// Semaines complètes d'affilée, avant la semaine en cours, avec au moins
    /// deux séances.
    static func trainingWeeks(_ dates: [Date], now: Date, calendar: Calendar) -> Int {
        var count = 0
        var reference = now
        // Borne de sécurité : deux ans.
        for _ in 0..<104 {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: reference),
                  let week = calendar.dateInterval(of: .weekOfYear, for: previous) else { break }
            // Fin exclusive, comme `WeeklyStreak`.
            guard dates.filter({ $0 >= week.start && $0 < week.end }).count >= 2 else { break }
            count += 1
            reference = previous
        }
        return count
    }

    /// Exercices travaillés ces trois dernières semaines dont le meilleur 1RM
    /// estimé des trois dernières séances ne dépasse pas celui des trois
    /// précédentes.
    static func stalledExercises(_ sessions: [Session], now: Date) -> Int {
        let recent = now.addingTimeInterval(-21 * 86_400)
        let sorted = sessions.sorted { $0.date < $1.date }
        let names = Set(sorted.filter { $0.date >= recent }.flatMap(\.best.keys))
        return names.filter { name in
            let values = sorted.compactMap { $0.best[name] }
            guard values.count >= 6 else { return false }
            let last = values.suffix(3).max() ?? 0
            let before = values.dropLast(3).suffix(3).max() ?? 0
            return last <= before
        }.count
    }
}

/// Semaine allégée en cours ou reportée, enregistrée dans les préférences.
enum DeloadStore {
    static let startKey = "deloadStart"
    static let snoozeKey = "deloadSnoozeUntil"

    static func start(defaults: UserDefaults = .standard) -> Date? {
        let value = defaults.double(forKey: startKey)
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    static func isActive(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard let start = start(defaults: defaults) else { return false }
        return now < start.addingTimeInterval(Double(Deload.lengthDays) * 86_400)
    }

    static func isSnoozed(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        now.timeIntervalSince1970 < defaults.double(forKey: snoozeKey)
    }
}

// MARK: - Remplacer un exercice

/// Équivalents d'un exercice quand la machine est prise.
///
/// Même muscle cible, en privilégiant un autre matériel, le matériel qu'on
/// trouve dans toute salle et les muscles secondaires en commun. Pour un
/// exercice saisi à la main, hors catalogue, on se rabat sur la zone devinée
/// d'après son nom.
enum ExerciseSwap {

    private static let commonEquipment: Set<String> = [
        "barbell", "dumbbell", "cable", "leverage machine", "smith machine",
        "body weight", "ez barbell", "kettlebell",
    ]

    static func alternatives(to exercise: CatalogExercise?, named name: String,
                             in catalog: [CatalogExercise], limit: Int = 8) -> [CatalogExercise] {
        let candidates: [CatalogExercise]
        if let exercise {
            candidates = catalog.filter { $0.id != exercise.id && $0.target == exercise.target }
        } else if let region = MuscleMap.guess(fromName: name).max(by: { $0.value < $1.value })?.key {
            candidates = catalog.filter {
                $0.category != "cardio"
                    && (MuscleMap.load(target: $0.target, secondary: [])[region] ?? 0) >= 1
            }
        } else {
            return []
        }

        func score(_ candidate: CatalogExercise) -> Int {
            var score = commonEquipment.contains(candidate.equipment) ? 3 : 0
            if let exercise {
                score += 2 * Set(candidate.secondary).intersection(exercise.secondary).count
                // La machine est prise : un autre matériel a plus de chances d'être libre.
                if candidate.equipment != exercise.equipment { score += 1 }
            }
            // Dans la liste curée des noms traduits : un exercice courant.
            if ExerciseNames.curated(id: candidate.id) != nil { score += 2 }
            // Variantes très spécifiques (« sur ballon, jambe levée… »).
            if candidate.name.split(separator: " ").count > 5 { score -= 2 }
            return score
        }

        var seen: Set<String> = [name.lowercased()]
        return candidates
            .map { (exercise: $0, score: score($0)) }
            .sorted { ($0.score, -$0.exercise.name.count) > ($1.score, -$1.exercise.name.count) }
            .map(\.exercise)
            .filter { seen.insert($0.displayName.lowercased()).inserted }
            .prefix(limit)
            .map { $0 }
    }
}
