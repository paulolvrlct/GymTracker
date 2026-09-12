import SwiftUI
import SwiftData

// MARK: - Nom d'exercice → zones sollicitées

/// Traduit un nom d'exercice en zones du corps.
///
/// Les séries enregistrées ne gardent que le nom de l'exercice. On retrouve donc
/// son entrée du catalogue (muscles cible et secondaires) via les séances types,
/// puis par le nom, et en dernier recours on devine à partir des mots du nom.
final class ExerciseRegionResolver {
    private var catalogIDByName: [String: String] = [:]
    private var cache: [String: [BodyRegion: Double]] = [:]

    /// Index nom → exercice, construit une seule fois pour tout le catalogue.
    private static let catalogByName: [String: CatalogExercise] = {
        var index: [String: CatalogExercise] = [:]
        for exercise in ExerciseCatalog.all {
            index[exercise.name.lowercased()] = exercise
            index[exercise.displayName.lowercased()] = exercise
        }
        return index
    }()

    init(templates: [WorkoutTemplate]) {
        for template in templates {
            for exercise in template.exercises {
                if let id = exercise.catalogID { catalogIDByName[exercise.name] = id }
            }
        }
    }

    func regions(for name: String) -> [BodyRegion: Double] {
        if let cached = cache[name] { return cached }
        let exercise = catalogIDByName[name].flatMap { ExerciseCatalog.find(id: $0) }
            ?? Self.catalogByName[name.lowercased()]
        let result = exercise.map { MuscleMap.load(target: $0.target, secondary: $0.secondary) }
            ?? MuscleMap.guess(fromName: name)
        cache[name] = result
        return result
    }
}

// MARK: - État du jour

/// Forme et recommandation du jour, recalculées à chaque affichage depuis
/// l'historique — même principe que `Progression` : rien n'est stocké, rien ne
/// peut se désynchroniser.
struct TodayState {
    let readiness: HybridReadiness
    let plan: TodayPlan

    /// Deux semaines suffisent : au-delà, la fatigue résiduelle est nulle et la
    /// série de jours actifs n'a besoin que de la dernière semaine.
    static let lookbackDays = 14

    static func make(templates: [WorkoutTemplate],
                     sessions: [WorkoutSession],
                     runs: [RunSession],
                     races: [HybridRaceResult] = [],
                     now: Date = .now) -> TodayState {
        let resolver = ExerciseRegionResolver(templates: templates)
        let since = now.addingTimeInterval(-Double(lookbackDays) * 86_400)
        let vma = VMAStore.value

        var loads: [TrainingLoad] = []
        for session in sessions where session.date >= since {
            loads.append(.workout(name: session.templateName, date: session.date,
                                  exerciseNames: session.sets.map(\.exerciseName),
                                  regions: resolver.regions(for:)))
        }
        for run in runs where run.date >= since {
            loads.append(.run(date: run.date, km: run.distanceKm,
                              paceSecPerKm: run.averagePaceSecPerKm, vma: vma))
        }
        for race in races where race.date >= since {
            loads.append(.hybridRace(date: race.date, completedSegments: race.splits.count))
        }
        let readiness = HybridReadiness(loads: loads, now: now)

        // `sessions` et `runs` arrivent triés du plus récent au plus ancien.
        let infos = templates.map { template in
            var templateLoads: [BodyRegion: Double] = [:]
            for exercise in template.exercises {
                for (region, value) in resolver.regions(for: exercise.name) {
                    templateLoads[region, default: 0] += value * Double(exercise.targetSets)
                }
            }
            return TodayPlan.TemplateInfo(
                name: template.name, loads: templateLoads,
                lastDone: sessions.first { $0.templateName == template.name }?.date)
        }

        let plan = TodayPlan.make(readiness: readiness, templates: infos,
                                  lastRun: runs.first?.date,
                                  lastWorkout: sessions.first?.date, now: now)
        return TodayState(readiness: readiness, plan: plan)
    }
}

// MARK: - Présentation des actions

extension TodayPlan.Action {
    var title: String {
        switch self {
        case .workout(let name): name
        case .hardRun: String(localized: "Course de qualité")
        case .easyRun: String(localized: "Footing facile")
        case .rest:    String(localized: "Repos")
        }
    }

    var symbol: String {
        switch self {
        case .workout: "dumbbell.fill"
        case .hardRun: "bolt.fill"
        case .easyRun: "figure.run"
        case .rest:    "bed.double.fill"
        }
    }

    @MainActor var tint: Color {
        switch self {
        case .workout: Color.brand
        case .hardRun, .easyRun: .green
        case .rest: .teal
        }
    }
}

/// Couleur d'un niveau de fraîcheur : vert au-delà du seuil de récupération.
func freshnessColor(_ value: Double) -> Color {
    switch value {
    case HybridReadiness.readyThreshold...: .green
    case 0.6...: .yellow
    case 0.4...: .orange
    default: .red
    }
}

// MARK: - Carte d'accueil

/// Répond à la question du matin : « qu'est-ce que je fais aujourd'hui ? ».
struct TodayCard: View {
    let state: TodayState
    var onOpenDetail: () -> Void
    var onStart: (TodayPlan.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ReadinessRing(score: state.readiness.score, size: 46, lineWidth: 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aujourd'hui")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(state.plan.action.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if state.plan.action != .rest {
                    Button {
                        onStart(state.plan.action)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(state.plan.action.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Lancer : \(state.plan.action.title)")
                }
            }

            Text(state.plan.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            RegionStrip(readiness: state.readiness)
        }
        .padding(14)
        .glassCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenDetail)
        .accessibilityAction(named: Text("Voir la récupération"), onOpenDetail)
    }
}

/// Anneau de la note de forme.
struct ReadinessRing: View {
    let score: Int
    var size: CGFloat = 46
    var lineWidth: CGFloat = 5

    var body: some View {
        let fraction = Double(score) / 100
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(freshnessColor(fraction),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded).monospacedDigit())
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Forme du jour : \(score) sur 100")
    }
}

/// Une barre par zone : l'état du corps en un coup d'œil.
struct RegionStrip: View {
    let readiness: HybridReadiness

    var body: some View {
        HStack(spacing: 6) {
            ForEach(BodyRegion.allCases) { region in
                let value = readiness.freshness(region)
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule().fill(freshnessColor(value))
                                .frame(width: max(4, geo.size.width * value))
                        }
                    }
                    .frame(height: 5)
                    Text(region.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(region.label) : \(readiness.percent(region)) %")
            }
        }
    }
}

// MARK: - Écran de détail

struct RecoveryDetailView: View {
    let state: TodayState
    var onStart: (TodayPlan.Action) -> Void

    private var readiness: HybridReadiness { state.readiness }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                planCard
                regionsCard
                if !readiness.recentLoads.isEmpty { recentCard }
                methodNote
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Récupération")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            ReadinessRing(score: readiness.score, size: 120, lineWidth: 12)
            Text("Forme du jour").font(.headline)
            Text(scoreComment)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var scoreComment: String {
        switch readiness.score {
        case 85...: String(localized: "Tout est au vert.")
        case 65...: String(localized: "Globalement récupéré, une zone encore entamée.")
        case 40...: String(localized: "Récupération en cours : choisis bien ta séance.")
        default:    String(localized: "Ton corps a besoin de souffler.")
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Aujourd'hui", systemImage: state.plan.action.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(state.plan.action.tint)
                .textCase(.uppercase)
            Text(state.plan.action.title).font(.title3.bold())
            Text(state.plan.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let alternative = state.plan.alternative {
                Text("Ou : \(alternative.title)")
                    .font(.footnote.weight(.medium))
            }
            if state.plan.action != .rest {
                Button {
                    onStart(state.plan.action)
                } label: {
                    Text("C'est parti")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.plan.action.tint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var regionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Par zone").font(.headline)
            ForEach(BodyRegion.allCases) { region in
                let value = readiness.freshness(region)
                HStack(spacing: 12) {
                    Image(systemName: region.symbol)
                        .font(.subheadline)
                        .foregroundStyle(freshnessColor(value))
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(region.label).font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(readiness.percent(region)) %")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.08))
                                Capsule().fill(freshnessColor(value))
                                    .frame(width: max(4, geo.size.width * value))
                            }
                        }
                        .frame(height: 6)
                        if let date = readiness.readyDate(region) {
                            Text(readyText(date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func readyText(_ date: Date) -> String {
        let calendar = Calendar.current
        let hourOfDay = calendar.component(.hour, from: date)

        // « Au vert demain vers 3 h » ne sert à rien : la nuit, on annonce le
        // matin qui suit.
        if hourOfDay < 7 || hourOfDay >= 22 {
            let morning = hourOfDay >= 22 ? (calendar.date(byAdding: .day, value: 1, to: date) ?? date) : date
            if calendar.isDateInToday(morning) { return String(localized: "Au vert ce matin") }
            if calendar.isDateInTomorrow(morning) { return String(localized: "Au vert demain matin") }
            let weekday = morning.formatted(.dateTime.weekday(.wide))
            return String(localized: "Au vert \(weekday) matin")
        }

        let hour = date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
        if calendar.isDateInToday(date) { return String(localized: "Au vert vers \(hour)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Au vert demain vers \(hour)") }
        let weekday = date.formatted(.dateTime.weekday(.wide))
        return String(localized: "Au vert \(weekday) vers \(hour)")
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ce qui pèse encore").font(.headline)
            ForEach(Array(readiness.recentLoads.prefix(6).enumerated()), id: \.offset) { _, load in
                HStack(spacing: 12) {
                    Image(systemName: symbol(for: load.source))
                        .foregroundStyle(.secondary)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: load.source)).font(.subheadline.weight(.medium))
                        Text(load.date.formatted(.relative(presentation: .named)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(mainRegions(of: load))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func symbol(for source: TrainingLoad.Source) -> String {
        switch source {
        case .workout: "dumbbell.fill"
        case .run: "figure.run"
        case .hybridRace: "flag.checkered"
        }
    }

    private func title(for source: TrainingLoad.Source) -> String {
        switch source {
        case .workout(let name): name
        case .run(let km):
            String(localized: "Course · \(km.formatted(.number.precision(.fractionLength(1)))) km")
        case .hybridRace: String(localized: "Simulation de course hybride")
        }
    }

    /// Les deux zones les plus sollicitées par une activité.
    private func mainRegions(of load: TrainingLoad) -> String {
        load.loads.sorted { $0.value > $1.value }
            .prefix(2)
            .map(\.key.label)
            .joined(separator: " · ")
    }

    private var methodNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Comment c'est calculé").font(.footnote.weight(.semibold))
            Text("Chaque série sollicite les muscles de son exercice, chaque kilomètre sollicite jambes et cardio, davantage quand l'allure est rapide. La fatigue s'estompe avec le temps : 48 à 72 h pour les jambes après une grosse séance.")
            Text("C'est une estimation à partir de ce que tu enregistres, pas un avis médical : tes sensations passent en premier.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}
