import WidgetKit
import SwiftUI
import SwiftData
import Charts

// MARK: - Widget Streak (jauge de jours consécutifs)

struct StreakEntry: TimelineEntry {
    let date: Date
    let status: WeeklyStreak.Status
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, status: .init(weeks: 4, thisWeek: 2, goal: 3))
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // Rafraîchit au changement de jour (le streak ne bouge pas plus vite)
        let nextMidnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        completion(Timeline(entries: [loadEntry()], policy: .after(nextMidnight)))
    }

    /// Lit la base SwiftData partagée (App Group) — même calcul que HomeView.
    private func loadEntry() -> StreakEntry {
        let goal = WeeklyStreak.goal
        guard let container = try? SharedStore.makeContainer() else {
            return StreakEntry(date: .now, status: .init(weeks: 0, thisWeek: 0, goal: goal))
        }
        let context = ModelContext(container)
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let runs = (try? context.fetch(FetchDescriptor<RunSession>())) ?? []
        let races = (try? context.fetch(FetchDescriptor<HybridRaceResult>())) ?? []
        let imported = (try? context.fetch(FetchDescriptor<ImportedActivity>())) ?? []
        let dates = sessions.map(\.date) + runs.map(\.date) + races.map(\.date) + imported.map(\.date)
        let status = WeeklyStreak.status(activityDates: dates, goal: goal)
        return StreakEntry(date: .now, status: status)
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        let status = entry.status
        VStack(spacing: 8) {
            Gauge(value: Double(min(status.thisWeek, status.goal)),
                  in: 0...Double(max(status.goal, 1))) {
                Image(systemName: "bolt.fill")
            } currentValueLabel: {
                Text("\(status.thisWeek)/\(status.goal)")
                    .font(.headline.bold())
            }
            .gaugeStyle(.accessoryCircular)
            .tint(status.isThisWeekDone ? .green : .indigo)

            Text(daysText(status.thisWeek))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(weeksText(status.weeks))
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func daysText(_ days: Int) -> LocalizedStringKey {
        days > 1 ? "jours actifs cette semaine" : "jour actif cette semaine"
    }

    private func weeksText(_ weeks: Int) -> LocalizedStringKey {
        switch weeks {
        case 0: "Objectif de la semaine"
        case 1: "1 semaine d'affilée"
        default: "\(weeks) semaines d'affilée"
        }
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Régularité")
        .description("Tes jours actifs de la semaine et tes semaines d'objectif tenues (muscu + course).")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget courbe de volume (Swift Charts)

struct VolumeWeek: Hashable {
    let start: Date
    let volume: Double
}

struct VolumeEntry: TimelineEntry {
    let date: Date
    let weeks: [VolumeWeek]
}

struct VolumeProvider: TimelineProvider {
    func placeholder(in context: Context) -> VolumeEntry {
        let cal = Calendar.current
        let weeks = (0..<6).reversed().map { offset in
            VolumeWeek(start: cal.date(byAdding: .weekOfYear, value: -offset, to: .now)!,
                       volume: Double([1800, 2400, 2100, 2900, 2600, 3200][offset]))
        }
        return VolumeEntry(date: .now, weeks: weeks)
    }

    func getSnapshot(in context: Context, completion: @escaping (VolumeEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VolumeEntry>) -> Void) {
        let nextMidnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        completion(Timeline(entries: [loadEntry()], policy: .after(nextMidnight)))
    }

    /// Volume soulevé (kg) par semaine sur les 6 dernières semaines
    private func loadEntry() -> VolumeEntry {
        let calendar = Calendar.current
        var weeks: [VolumeWeek] = []
        guard let container = try? SharedStore.makeContainer() else {
            return VolumeEntry(date: .now, weeks: [])
        }
        let context = ModelContext(container)
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        for offset in (0..<6).reversed() {
            guard let ref = calendar.date(byAdding: .weekOfYear, value: -offset, to: .now),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: ref) else { continue }
            let volume = sessions
                .filter { interval.contains($0.date) }
                .reduce(0) { $0 + $1.totalVolume }
            weeks.append(VolumeWeek(start: interval.start, volume: volume))
        }
        return VolumeEntry(date: .now, weeks: weeks)
    }
}

struct VolumeChartWidgetView: View {
    let entry: VolumeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.indigo)
                Text("Volume soulevé · 6 semaines")
                    .font(.caption.weight(.semibold))
                Spacer()
            }

            if entry.weeks.allSatisfy({ $0.volume == 0 }) {
                Text("Termine une séance pour voir ta courbe 💪")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(entry.weeks, id: \.start) { week in
                    BarMark(
                        x: .value("Semaine", week.start, unit: .weekOfYear),
                        y: .value("kg", week.volume)
                    )
                    .foregroundStyle(.indigo)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.narrow), centered: true)
                            .font(.system(size: 8))
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct VolumeChartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VolumeChartWidget", provider: VolumeProvider()) { entry in
            VolumeChartWidgetView(entry: entry)
        }
        .configurationDisplayName("Volume d'entraînement")
        .description("Ton volume soulevé par semaine (Swift Charts).")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget calories du jour (anneau)

struct CalorieEntry: TimelineEntry {
    let date: Date
    let consumed: Double
    let target: Double
}

struct CalorieProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieEntry {
        CalorieEntry(date: .now, consumed: 1450, target: 2400)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieEntry>) -> Void) {
        // L'app force un rafraîchissement à chaque ajout au journal ;
        // le repli de 30 min couvre le passage à minuit et les jours sans app.
        completion(Timeline(entries: [loadEntry()], policy: .after(.now.addingTimeInterval(1800))))
    }

    private func loadEntry() -> CalorieEntry {
        let target = SharedStore.groupDefaults?.double(forKey: SharedStore.nutritionTargetKey) ?? 0
        guard let container = try? SharedStore.makeContainer() else {
            return CalorieEntry(date: .now, consumed: 0, target: target > 0 ? target : 2200)
        }
        let context = ModelContext(container)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let consumed = entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.kcal }
        return CalorieEntry(date: .now, consumed: consumed, target: target > 0 ? target : 2200)
    }
}

struct CalorieWidgetView: View {
    let entry: CalorieEntry
    @Environment(\.widgetFamily) private var family

    private var progress: Double { min(entry.consumed / max(entry.target, 1), 1) }
    private var over: Bool { entry.consumed > entry.target }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "fork.knife")
            } currentValueLabel: {
                Text("\(Int(entry.consumed))")
                    .font(.system(size: 14, weight: .semibold))
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(.fill.tertiary, for: .widget)
        default:
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(over ? Color.orange : Color.indigo,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(entry.consumed))")
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("objectif \(Int(entry.target)) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct CalorieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalorieWidget", provider: CalorieProvider()) { entry in
            CalorieWidgetView(entry: entry)
        }
        .configurationDisplayName("Calories du jour")
        .description("Ton anneau calories : consommé vs objectif.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - Widget raccourci course

struct RunShortcutEntry: TimelineEntry {
    let date: Date
}

struct RunShortcutProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunShortcutEntry { RunShortcutEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (RunShortcutEntry) -> Void) {
        completion(RunShortcutEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RunShortcutEntry>) -> Void) {
        completion(Timeline(entries: [RunShortcutEntry(date: .now)], policy: .never))
    }
}

struct RunShortcutWidgetView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(colors: [.green, .teal],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
            Text("Courir")
                .font(.headline)
        }
        // Ouvre l'app directement sur l'onglet Course (géré par RootTabView.onOpenURL)
        .widgetURL(URL(string: "gymtracker://run"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct RunShortcutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RunShortcutWidget", provider: RunShortcutProvider()) { _ in
            RunShortcutWidgetView()
        }
        .configurationDisplayName("Démarrer une course")
        .description("Raccourci direct vers le mode course GPS.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Forme du jour

struct ReadinessEntry: TimelineEntry {
    let date: Date
    /// nil tant que l'app n'a jamais publié de prévision.
    let point: ReadinessForecastPoint?
}

struct ReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: .now,
                       point: ReadinessForecastPoint(date: .now, score: 82, title: "Séance B"))
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(currentEntry())
    }

    /// Une entrée par point de la prévision encore à venir : le widget change
    /// de lui-même au fil des heures, sans réveiller l'app.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let points = ReadinessForecast.load()
        let now = Date.now
        // Le point en cours puis tous les suivants.
        let upcoming = points.filter { $0.date > now }
        var entries = [ReadinessEntry(date: now, point: Self.current(in: points, at: now))]
        entries += upcoming.map { ReadinessEntry(date: $0.date, point: $0) }
        // Prévision épuisée (app pas ouverte depuis deux jours) : pas de
        // rechargement en boucle, on repasse dans quelques heures.
        let policy: TimelineReloadPolicy = upcoming.isEmpty
            ? .after(now.addingTimeInterval(6 * 3600)) : .atEnd
        completion(Timeline(entries: entries, policy: policy))
    }

    private func currentEntry() -> ReadinessEntry {
        ReadinessEntry(date: .now, point: Self.current(in: ReadinessForecast.load(), at: .now))
    }

    /// Point en vigueur à cette heure. Plus de 3 h après le dernier point, la
    /// prévision est périmée : mieux vaut inviter à ouvrir l'app qu'afficher
    /// une forme qui ignore les derniers jours.
    static func current(in points: [ReadinessForecastPoint], at date: Date) -> ReadinessForecastPoint? {
        guard let point = points.last(where: { $0.date <= date }) ?? points.first else { return nil }
        return date.timeIntervalSince(point.date) <= 3 * 3600 ? point : nil
    }
}

struct ReadinessWidgetView: View {
    let entry: ReadinessEntry
    @Environment(\.widgetFamily) private var family

    private var tint: Color {
        guard let score = entry.point?.score else { return .secondary }
        switch score {
        case 80...: return .green
        case 60...: return .yellow
        case 40...: return .orange
        default:    return .red
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            default: small
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circular: some View {
        Gauge(value: Double(entry.point?.score ?? 0), in: 0...100) {
            Image(systemName: "bolt.heart.fill")
        } currentValueLabel: {
            Text(entry.point.map { "\($0.score)" } ?? "–")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Forme du jour").font(.caption2.weight(.semibold))
            if let point = entry.point {
                Text("\(point.score) · \(point.title)")
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text("Ouvre LiftRun").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle().stroke(tint.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: Double(entry.point?.score ?? 0) / 100)
                        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(entry.point.map { "\($0.score)" } ?? "–")
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                }
                .frame(width: 50, height: 50)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text("Aujourd'hui")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if let point = entry.point {
                Text(point.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            } else {
                Text("Ouvre LiftRun pour calculer ta forme.")
                    .font(.caption)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ReadinessWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ReadinessForecast.widgetKind, provider: ReadinessProvider()) { entry in
            ReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("Forme du jour")
        .description("Ta forme du jour et la séance conseillée, muscu et course confondues.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
