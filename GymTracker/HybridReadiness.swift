import Foundation

// MARK: - Zones du corps

/// Les grandes zones qu'un athlète hybride sollicite, muscu et course confondues.
///
/// Volontairement peu nombreuses : sept zones se lisent d'un coup d'œil, trente
/// muscles non. Les jambes forment une seule zone parce que c'est *la* zone
/// partagée : le squat du lundi et le fractionné du mardi puisent dans le même
/// réservoir. C'est précisément ce qu'une app de muscu seule, ou de course
/// seule, ne peut pas voir.
enum BodyRegion: String, CaseIterable, Identifiable {
    case legs, back, chest, shoulders, arms, core, cardio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .legs:      String(localized: "body.region.legs")
        case .back:      String(localized: "body.region.back")
        case .chest:     String(localized: "body.region.chest")
        case .shoulders: String(localized: "body.region.shoulders")
        case .arms:      String(localized: "body.region.arms")
        case .core:      String(localized: "body.region.core")
        case .cardio:    String(localized: "body.region.cardio")
        }
    }

    var symbol: String {
        switch self {
        case .legs:      "figure.walk"
        case .back:      "figure.climbing"
        case .chest:     "figure.strengthtraining.traditional"
        case .shoulders: "figure.arms.open"
        case .arms:      "dumbbell.fill"
        case .core:      "figure.core.training"
        case .cardio:    "heart.fill"
        }
    }

    /// Demi-vie de la fatigue, en heures.
    ///
    /// Calée sur les 48 à 72 h de récupération généralement admises après un
    /// travail lourd : les grosses masses musculaires récupèrent plus lentement
    /// que les petites.
    var halfLifeHours: Double {
        switch self {
        case .legs:      28
        case .back:      26
        case .chest:     24
        case .shoulders: 22
        case .arms:      20
        case .core:      18
        case .cardio:    20
        }
    }

    /// Charge qui « vide » complètement la zone, en séries dures (ou en
    /// kilomètres pondérés pour le cardio). Une grosse séance jambes de 16 à
    /// 20 séries l'atteint ; une séance modérée en consomme la moitié.
    var capacity: Double {
        switch self {
        case .legs:      18
        case .back:      14
        case .chest:     14
        case .shoulders: 12
        case .arms:      16
        case .core:      12
        case .cardio:    15
        }
    }

    /// Poids dans la note de forme globale : les jambes et le cardio conditionnent
    /// presque toutes les séances d'un athlète hybride, les bras presque aucune.
    var scoreWeight: Double {
        switch self {
        case .legs:   2
        case .cardio: 1.5
        case .arms, .core: 0.5
        default:      1
        }
    }
}

// MARK: - Muscles → zones

enum MuscleMap {

    /// Vocabulaire fermé du catalogue d'exercices (`target` et `secondary`).
    static let regionOfMuscle: [String: BodyRegion] = [
        // jambes
        "quads": .legs, "quadriceps": .legs, "glutes": .legs, "hamstrings": .legs,
        "calves": .legs, "soleus": .legs, "adductors": .legs, "abductors": .legs,
        "inner thighs": .legs, "groin": .legs, "ankles": .legs, "ankle stabilizers": .legs,
        "feet": .legs, "shins": .legs,
        // dos
        "lats": .back, "latissimus dorsi": .back, "upper back": .back, "back": .back,
        "rhomboids": .back, "traps": .back, "trapezius": .back, "lower back": .back,
        "spine": .back, "levator scapulae": .back,
        // pectoraux
        "pectorals": .chest, "chest": .chest, "upper chest": .chest, "serratus anterior": .chest,
        // épaules
        "delts": .shoulders, "deltoids": .shoulders, "shoulders": .shoulders,
        "rear deltoids": .shoulders, "rotator cuff": .shoulders,
        // bras
        "biceps": .arms, "triceps": .arms, "forearms": .arms, "brachialis": .arms,
        "wrists": .arms, "wrist flexors": .arms, "wrist extensors": .arms,
        "hands": .arms, "grip muscles": .arms,
        // tronc
        "abs": .core, "abdominals": .core, "lower abs": .core, "core": .core,
        "obliques": .core, "hip flexors": .core,
        // cardio
        "cardiovascular system": .cardio,
    ]

    /// Sollicitation d'un exercice : 1 pour la zone du muscle cible, 0,5 pour
    /// celles des muscles secondaires. Une zone n'est comptée qu'une fois par
    /// série, au plus fort : un développé couché (pectoraux + haut des pecs) ne
    /// compte pas double.
    static func load(target: String, secondary: [String]) -> [BodyRegion: Double] {
        var result: [BodyRegion: Double] = [:]
        for muscle in secondary {
            if let region = regionOfMuscle[muscle] {
                result[region] = max(result[region] ?? 0, 0.5)
            }
        }
        if let region = regionOfMuscle[target] { result[region] = 1 }
        return result
    }

    /// Repli quand l'exercice n'est pas relié au catalogue (saisi à la main) : on
    /// devine la zone à partir du nom, en français, anglais ou espagnol.
    ///
    /// L'ordre des règles compte : « relevé de jambes » est un exercice d'abdos
    /// et « développé militaire » un exercice d'épaules, alors que « jambes » et
    /// « développé » renverraient ailleurs.
    static func guess(fromName name: String) -> [BodyRegion: Double] {
        let text = name.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        for (keywords, region) in guessRules where keywords.contains(where: { text.contains($0) }) {
            return [region: 1]
        }
        return [:]
    }

    private static let guessRules: [([String], BodyRegion)] = [
        (["leg raise", "releve de jambes", "releves de jambes", "elevacion de piernas",
          "crunch", "gainage", "planche", "plank", "abdo", "russian twist", "oblique",
          "ab wheel", "roue abdo", "core"], .core),
        (["militaire", "military", "militar", "overhead", "epaule", "shoulder", "hombro",
          "elevation laterale", "elevations laterales", "lateral raise", "face pull",
          "arnold", "oiseau"], .shoulders),
        (["squat", "sentadilla", "presse a cuisses", "presse", "leg press", "leg ext",
          "leg curl", "jambe", "fente", "lunge", "zancada", "mollet", "calf", "gemelo",
          "souleve", "deadlift", "peso muerto", "hip thrust", "fessier", "glute", "gluteo",
          "ischio", "hamstring", "quadri", "cuisse", "box jump", "wall ball", "sled",
          "traineau", "step up", "burpee"], .legs),
        (["developpe couche", "developpe incline", "bench", "pec", "chest", "pecho",
          "pompe", "push-up", "push up", "flexion", "butterfly", "ecarte", "fly",
          "press banca", "chest press"], .chest),
        (["traction", "pull-up", "pull up", "pullup", "chin", "rowing", "row", "remo",
          "tirage", "pulldown", "dos", "back", "espalda", "dominada", "shrug",
          "trapeze", "lat "], .back),
        (["curl", "biceps", "triceps", "marteau", "hammer", "extension", "barre au front",
          "skull", "dips", "fondos", "avant-bras", "forearm", "antebrazo"], .arms),
    ]
}

// MARK: - Charge d'entraînement

/// Une séance, une course ou une simulation de course hybride, traduite en
/// charge par zone. C'est le point de rencontre des deux mondes : une fois
/// ici, un kilomètre et une série se comparent.
struct TrainingLoad {
    enum Source: Equatable {
        case workout(name: String)
        case run(km: Double)
        case hybridRace
    }

    let date: Date
    let source: Source
    let loads: [BodyRegion: Double]

    /// Séance de musculation : chaque série sollicite les zones de son exercice.
    static func workout(name: String, date: Date, exerciseNames: [String],
                        regions: (String) -> [BodyRegion: Double]) -> TrainingLoad {
        var loads: [BodyRegion: Double] = [:]
        for exercise in exerciseNames {
            for (region, value) in regions(exercise) {
                loads[region, default: 0] += value
            }
        }
        return TrainingLoad(date: date, source: .workout(name: name), loads: loads)
    }

    /// Course : les jambes et le cardio, d'autant plus que l'allure est rapide.
    ///
    /// Sans VMA connue, toutes les courses comptent comme de l'endurance : on
    /// sous-estime alors la fatigue d'un fractionné plutôt que d'inventer une
    /// intensité.
    static func run(date: Date, km: Double, paceSecPerKm: Double, vma: Double?) -> TrainingLoad {
        let intensity = intensityFactor(paceSecPerKm: paceSecPerKm, vma: vma)
        return TrainingLoad(date: date, source: .run(km: km), loads: [
            .legs: km * 0.8 * intensity,
            .cardio: km * intensity,
        ])
    }

    /// Simulation de course hybride (8 × 1 km + 8 ateliers) : l'une des séances
    /// les plus coûteuses qui soient, tout le corps y passe.
    static func hybridRace(date: Date, completedSegments: Int) -> TrainingLoad {
        let share = min(1, Double(completedSegments) / 16)
        let full: [BodyRegion: Double] = [
            .legs: 20, .cardio: 16, .back: 5, .shoulders: 4, .arms: 4, .core: 4, .chest: 2,
        ]
        return TrainingLoad(date: date, source: .hybridRace,
                            loads: full.mapValues { $0 * share })
    }

    static func intensityFactor(paceSecPerKm: Double, vma: Double?) -> Double {
        guard let vma, vma > 0, paceSecPerKm > 0, paceSecPerKm.isFinite else { return 1 }
        let ratio = (3600 / paceSecPerKm) / vma
        if ratio >= 0.9 { return 1.6 }
        if ratio >= 0.82 { return 1.3 }
        return 1
    }
}

// MARK: - Forme du jour

/// État de récupération de chaque zone, à un instant donné.
///
/// Modèle volontairement simple et explicable : chaque charge décroît de moitié
/// à chaque demi-vie de sa zone. Pas de boîte noire : l'écran de détail peut
/// dire exactement d'où vient chaque pourcentage.
struct HybridReadiness {

    /// Au-delà de 80 % de fraîcheur, une zone est considérée comme récupérée.
    static let readyThreshold = 0.8
    /// Les charges plus anciennes sont négligeables (moins de 7 % restant aux
    /// jambes) : inutile de les parcourir.
    static let horizonDays = 5

    let now: Date
    /// Charge résiduelle par zone, dans l'unité de `BodyRegion.capacity`.
    let fatigue: [BodyRegion: Double]
    /// Charges des derniers jours, les plus récentes d'abord.
    let recentLoads: [TrainingLoad]
    /// Jours consécutifs avec au moins une activité, jusqu'à aujourd'hui (ou
    /// hier si rien n'a encore été fait aujourd'hui).
    let consecutiveActiveDays: Int

    init(loads: [TrainingLoad], now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        let horizon = now.addingTimeInterval(-Double(Self.horizonDays) * 86_400)
        let recent = loads.filter { $0.date >= horizon && $0.date <= now }
            .sorted { $0.date > $1.date }
        recentLoads = recent

        var fatigue: [BodyRegion: Double] = [:]
        for load in recent {
            let hours = now.timeIntervalSince(load.date) / 3600
            for (region, value) in load.loads {
                fatigue[region, default: 0] += value * pow(0.5, hours / region.halfLifeHours)
            }
        }
        self.fatigue = fatigue

        let days = Set(loads.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        consecutiveActiveDays = count
    }

    /// Fraîcheur d'une zone, entre 0 (vidée) et 1 (pleinement récupérée).
    func freshness(_ region: BodyRegion) -> Double {
        let residual = fatigue[region] ?? 0
        return max(0, min(1, 1 - residual / region.capacity))
    }

    func percent(_ region: BodyRegion) -> Int { Int((freshness(region) * 100).rounded()) }

    /// Note de forme globale, de 0 à 100.
    var score: Int {
        let totalWeight = BodyRegion.allCases.reduce(0) { $0 + $1.scoreWeight }
        let weighted = BodyRegion.allCases.reduce(0) { $0 + freshness($1) * $1.scoreWeight }
        return Int((weighted / totalWeight * 100).rounded())
    }

    /// Moment où la zone repasse au-dessus du seuil de récupération, ou nil si
    /// elle y est déjà.
    ///
    /// Toutes les charges d'une zone décroissent à la même vitesse : la fatigue
    /// totale suit donc elle-même une loi de demi-vie, et le calcul est exact.
    func readyDate(_ region: BodyRegion) -> Date? {
        let residual = fatigue[region] ?? 0
        let limit = (1 - Self.readyThreshold) * region.capacity
        guard residual > limit else { return nil }
        let hours = region.halfLifeHours * log2(residual / limit)
        return now.addingTimeInterval(hours * 3600)
    }

    /// Zone la moins récupérée, si elle est réellement entamée.
    var mostFatigued: BodyRegion? {
        let region = BodyRegion.allCases.min { freshness($0) < freshness($1) }
        guard let region, freshness(region) < 0.65 else { return nil }
        return region
    }

    /// Dernière activité ayant sollicité une zone : sert à expliquer un
    /// pourcentage (« après ta course d'hier »).
    func lastCause(of region: BodyRegion) -> TrainingLoad? {
        recentLoads.first { ($0.loads[region] ?? 0) >= 1 }
    }
}

// MARK: - Que faire aujourd'hui ?

/// La recommandation du jour : une action principale, une alternative, et la
/// raison en une phrase.
///
/// Règles volontairement lisibles plutôt qu'un score opaque : un conseil qu'on
/// ne comprend pas ne se suit pas.
struct TodayPlan: Equatable {

    enum Action: Equatable {
        case workout(templateName: String)
        case hardRun
        case easyRun
        case rest
    }

    let action: Action
    let reason: String
    let alternative: Action?

    /// Séance type, vue par le planificateur.
    struct TemplateInfo {
        let name: String
        /// Charge par zone qu'impose la séance complète.
        let loads: [BodyRegion: Double]
        let lastDone: Date?
    }

    static func make(readiness r: HybridReadiness,
                     templates: [TemplateInfo],
                     lastRun: Date?,
                     lastWorkout: Date?,
                     now: Date = .now) -> TodayPlan {

        // 1. Six jours d'affilée : le repos passe avant tout.
        if r.consecutiveActiveDays >= 6 {
            return TodayPlan(action: .rest,
                             reason: String(localized: "\(r.consecutiveActiveDays) jours d'activité d'affilée. C'est pendant le repos que le corps progresse : journée off aujourd'hui."),
                             alternative: r.freshness(.legs) >= 0.5 ? .easyRun : nil)
        }

        // 2. Tout est entamé : récupération active.
        if r.score < 40 {
            return TodayPlan(action: .rest,
                             reason: String(localized: "Ton corps encaisse encore les derniers jours (forme \(r.score) %). Repos ou marche tranquille, et ça repart demain."),
                             alternative: nil)
        }

        // 3. Meilleure séance de muscu : la plus fraîche parmi celles qu'on n'a
        //    pas faites depuis le plus longtemps.
        func readiness(of template: TemplateInfo) -> Double {
            let total = template.loads.values.reduce(0, +)
            guard total > 0 else { return 1 }
            return template.loads.reduce(0) { $0 + $1.value * r.freshness($1.key) } / total
        }
        func daysSince(_ date: Date?) -> Double {
            guard let date else { return 30 }
            return now.timeIntervalSince(date) / 86_400
        }
        let candidates = templates.filter { readiness(of: $0) >= 0.7 }
        let bestTemplate = candidates.max { a, b in
            let da = daysSince(a.lastDone), db = daysSince(b.lastDone)
            if abs(da - db) >= 1 { return da < db }
            return readiness(of: a) < readiness(of: b)
        }

        // 4. Course possible ?
        let legs = r.freshness(.legs), cardio = r.freshness(.cardio)
        let run: Action? = legs >= 0.8 && cardio >= 0.8 ? .hardRun
                         : legs >= 0.5 && cardio >= 0.5 ? .easyRun
                         : nil

        // 5. On ne pousse pas une discipline que la personne ne pratique pas :
        //    un pur pratiquant de muscu ne verra la course qu'en alternative.
        let runsLately = lastRun.map { daysSince($0) <= 30 } ?? false
        let liftsLately = lastWorkout.map { daysSince($0) <= 30 } ?? false
        let hasHistory = lastRun != nil || lastWorkout != nil

        var preferRun = false
        if let run, runsLately {
            if !liftsLately && hasHistory {
                preferRun = true
            } else if bestTemplate == nil {
                preferRun = true
            } else {
                // Équilibre hybride : la discipline délaissée depuis le plus longtemps.
                preferRun = daysSince(lastRun) > daysSince(lastWorkout) + 0.5
                    && (run == .hardRun || bestTemplate == nil)
            }
        }

        let workoutAction = bestTemplate.map { Action.workout(templateName: $0.name) }

        if preferRun, let run {
            return TodayPlan(action: run,
                             reason: reason(for: run, readiness: r, now: now),
                             alternative: workoutAction)
        }
        if let workoutAction {
            return TodayPlan(action: workoutAction,
                             reason: reason(for: workoutAction, readiness: r, now: now),
                             alternative: run)
        }
        if let run {
            return TodayPlan(action: run, reason: reason(for: run, readiness: r, now: now),
                             alternative: nil)
        }
        return TodayPlan(action: .rest,
                         reason: String(localized: "Aucune séance n'est assez récupérée aujourd'hui. Mobilité, marche ou repos complet : c'est aussi de l'entraînement."),
                         alternative: nil)
    }

    // MARK: Raison

    private static func reason(for action: Action, readiness r: HybridReadiness, now: Date) -> String {
        // La zone la plus entamée, et ce qui l'a entamée : c'est la phrase qui
        // montre que l'app a compris la semaine de la personne.
        if let tired = r.mostFatigued {
            let status = statusLine(region: tired, readiness: r, now: now)
            switch action {
            case .workout:
                return status + " " + String(localized: "Cette séance laisse la zone récupérer.")
            case .easyRun:
                return status + " " + String(localized: "Un footing facile de 30 à 40 min entretient le cardio sans freiner la récupération.")
            case .hardRun:
                return status + " " + String(localized: "Jambes et cardio au vert : bon jour pour une séance de qualité.")
            case .rest:
                return status
            }
        }
        switch action {
        case .workout(let name):
            // « Tout est récupéré » seulement si c'est vrai : à 80 %, des barres
            // jaunes à côté de cette phrase la contrediraient.
            if r.score >= 90 {
                return String(localized: "Tout est récupéré (forme \(r.score) %). Parfait pour \(name).")
            }
            return String(localized: "Forme \(r.score) % : \(name) sollicite surtout des zones reposées.")
        case .hardRun:
            return String(localized: "Jambes et cardio au vert : bon jour pour du fractionné ou un tempo.")
        case .easyRun:
            return String(localized: "Un footing facile de 30 à 40 min entretient le cardio sans freiner la récupération.")
        case .rest:
            return String(localized: "Journée de récupération.")
        }
    }

    /// « Jambes : 41 % après ta course d'hier. »
    static func statusLine(region: BodyRegion, readiness r: HybridReadiness, now: Date,
                           calendar: Calendar = .current) -> String {
        let pct = r.percent(region)
        let label = region.label
        guard let cause = r.lastCause(of: region) else {
            return String(localized: "\(label) : \(pct) %.")
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let isYesterday = calendar.isDate(cause.date, inSameDayAs: yesterday)
        let isToday = calendar.isDate(cause.date, inSameDayAs: now)
        let weekday = cause.date.formatted(.dateTime.weekday(.wide))

        switch cause.source {
        case .run:
            if isToday { return String(localized: "\(label) : \(pct) % après ta course du jour.") }
            if isYesterday { return String(localized: "\(label) : \(pct) % après ta course d'hier.") }
            return String(localized: "\(label) : \(pct) % après ta course de \(weekday).")
        case .hybridRace:
            return String(localized: "\(label) : \(pct) % après ta simulation de course hybride.")
        case .workout:
            if isToday { return String(localized: "\(label) : \(pct) % après ta séance du jour.") }
            if isYesterday { return String(localized: "\(label) : \(pct) % après ta séance d'hier.") }
            return String(localized: "\(label) : \(pct) % après ta séance de \(weekday).")
        }
    }
}
