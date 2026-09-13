import SwiftUI
import SwiftData
import StoreKit
import WidgetKit

struct HomeView: View {
    @Query(sort: \WorkoutTemplate.order) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \RunSession.date, order: .reverse) private var runs: [RunSession]
    @Query private var intakes: [SupplementIntake]
    @Query private var allSets: [SetRecord]
    @Query private var food: [FoodEntry]
    @Query(sort: \HybridRaceResult.date, order: .reverse) private var races: [HybridRaceResult]
    @Query(sort: \ImportedActivity.date, order: .reverse) private var importedActivities: [ImportedActivity]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    /// Lecture d'Apple Santé (entraînements, sommeil, VFC), activée par la personne.
    @AppStorage("healthImportEnabled") private var healthImportEnabled = false
    @State private var signals: RecoverySignals?
    /// Le point du matin, activé et réglé depuis le profil.
    @AppStorage(MorningBriefing.enabledKey) private var morningBriefing = false
    @AppStorage(MorningBriefing.hourKey) private var briefingHour = MorningBriefing.defaultHour
    @AppStorage(MorningBriefing.minuteKey) private var briefingMinute = 0
    /// Siri, Raccourcis et widget « Forme du jour » : lancer la séance du jour.
    @ObservedObject private var router = AppRouter.shared
    /// Ce que la personne pratique : la carte « Aujourd'hui » en dépend.
    @AppStorage(TrainingFocus.key) private var focusRaw = TrainingFocus.hybrid.rawValue
    /// Semaine allégée en cours (début) ou reportée (jusqu'à).
    @AppStorage(DeloadStore.startKey) private var deloadStart: Double = 0
    @AppStorage(DeloadStore.snoozeKey) private var deloadSnooze: Double = 0

    /// Onglet affiché par `RootTabView` : la carte « Aujourd'hui » y bascule
    /// quand elle recommande une course.
    var tabSelection: Binding<Int> = .constant(0)

    @State private var activeTemplate: WorkoutTemplate?
    @State private var showLibrary = false
    @State private var showProfile = false
    @State private var showRecovery = false
    @AppStorage("profileName") private var profileName = ""
    /// Observé pour que l'accord se mette à jour dès que le genre change au profil.
    @AppStorage("profileSex") private var profileSexRaw = UserSex.unspecified.rawValue
    /// Partagé avec le widget via l'App Group.
    @AppStorage(WeeklyStreak.goalKey, store: SharedStore.groupDefaults)
    private var weeklyGoal = WeeklyStreak.defaultGoal
    @State private var showGoalSheet = false
    @State private var showRecap = false
    #if DEBUG
    @State private var showShareCardsPreview = false
    @State private var showProgressionDebug = false
    @State private var showDataDebug = false
    #endif
    @Environment(\.requestReview) private var requestReview

    private var calendar: Calendar { Calendar.current }

    /// Recalculé à chaque rendu : voir `Progression` pour le pourquoi.
    private var progression: Progression {
        Progression(workouts: sessions, runs: runs, intakes: intakes)
    }

    /// Paliers hybrides, recalculés à la volée comme la progression.
    private var milestones: [MilestoneStatus] {
        Milestones.evaluate(
            workouts: sessions.map { (date: $0.date, volumeKg: $0.totalVolume) },
            runs: runs.map { Milestones.Run(date: $0.date, km: $0.distanceKm,
                                            durationSeconds: $0.durationSeconds) },
            raceDates: races.map(\.date),
            weeklyStreak: weekly.weeks)
    }

    private var sessionsThisWeek: Int {
        sessions.filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear) }.count
    }
    private var volumeThisMonth: Int {
        Int(sessions
            .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalVolume })
    }
    private var kmThisMonth: Double {
        runs.filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.distanceKm }
    }
    /// Régularité à la semaine : les jours de repos ne cassent rien (voir
    /// `WeeklyStreak` pour le pourquoi).
    private var weekly: WeeklyStreak.Status {
        WeeklyStreak.status(activityDates: activityDates, goal: weeklyGoal)
    }
    private var activityDates: [Date] {
        sessions.map(\.date) + runs.map(\.date) + races.map(\.date) + importedActivities.map(\.date)
    }

    private var greeting: String {
        let h = calendar.component(.hour, from: .now)
        switch h {
        case 5..<12: return String(localized: "Bonjour")
        case 12..<18: return String(localized: "Bon aprèm")
        default: return String(localized: "Bonsoir")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    TodayCard(state: today,
                              onOpenDetail: { showRecovery = true },
                              onStart: start)
                    deloadSection
                    NavigationLink {
                        ProgressionDetailView(progression: progression, milestones: milestones)
                    } label: {
                        LevelCard(progression: progression)
                    }
                    .buttonStyle(.plain)
                    statsGrid
                    if hasActivityThisWeek { shareWeekButton }
                    NavigationLink {
                        NutritionView()
                    } label: {
                        NutritionHomeCard()
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        SupplementsView()
                    } label: {
                        SupplementsCard()
                    }
                    .buttonStyle(.plain)
                    quickStartSection
                    recentActivitySection
                    footerSignature
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationTitle("Accueil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Mon profil")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLibrary = true
                    } label: {
                        Image(systemName: "books.vertical.fill")
                    }
                    .accessibilityLabel("Bibliothèque d'exercices")
                }
            }
            .navigationDestination(isPresented: $showRecovery) {
                RecoveryDetailView(state: today, onStart: start)
            }
            #if DEBUG
            .onAppear {
                // Captures d'écran automatisées : `-debugOpenRecovery YES`.
                if UserDefaults.standard.bool(forKey: "debugOpenRecovery") { showRecovery = true }
                if UserDefaults.standard.bool(forKey: "debugOpenRecap") { showRecap = true }
                if UserDefaults.standard.bool(forKey: "debugOpenShareCards") { showShareCardsPreview = true }
                if UserDefaults.standard.bool(forKey: "debugOpenProgression") { showProgressionDebug = true }
                if UserDefaults.standard.bool(forKey: "debugOpenData") { showDataDebug = true }
                // `-debugStartWorkout YES` : la séance B, la plus longue de la démo.
                if UserDefaults.standard.bool(forKey: "debugStartWorkout") {
                    activeTemplate = templates.dropFirst().first ?? templates.first
                }
            }
            .sheet(isPresented: $showShareCardsPreview) { ShareCardsPreview() }
            .sheet(isPresented: $showDataDebug) { NavigationStack { DataToolsView() } }
            .navigationDestination(isPresented: $showProgressionDebug) {
                ProgressionDetailView(progression: progression, milestones: milestones)
            }
            #endif
            .sheet(isPresented: $showLibrary) {
                ExerciseLibraryView()
            }
            .sheet(isPresented: $showGoalSheet) {
                WeeklyGoalSheet(goal: $weeklyGoal, activityDates: activityDates)
            }
            .sheet(isPresented: $showRecap) {
                WeeklyRecapSheet(recap: weekRecap)
            }
            .onChange(of: weeklyGoal) {
                WidgetCenter.shared.reloadTimelines(ofKind: "StreakWidget")
            }
            // Prévision de forme pour le widget : republiée à chaque nouvelle
            // activité, et au retour sur l'accueil pour couvrir les 48 h suivantes.
            .task(id: forecastSignature) {
                TodayState.publishForecast(templates: templates, sessions: sessions,
                                           runs: runs, races: races,
                                           imported: importedActivities, signals: signals)
                if morningBriefing {
                    TodayState.scheduleMorningBriefing(templates: templates, sessions: sessions,
                                                       runs: runs, races: races,
                                                       imported: importedActivities, signals: signals,
                                                       hour: briefingHour, minute: briefingMinute)
                } else {
                    NotificationManager.shared.cancelMorningBriefing()
                }
            }
            // Apple Santé : import et signaux de récupération, à l'ouverture,
            // à l'activation de l'option et au retour au premier plan.
            .task(id: healthImportEnabled) { await refreshHealth() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshHealth() } }
            }
            // Demande reçue au lancement comme en cours de route : `$pending`
            // renvoie sa valeur actuelle dès l'abonnement.
            .onReceive(router.$pending) { request in
                guard request == .startToday else { return }
                router.pending = nil
                startToday()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .fullScreenCover(item: $activeTemplate,
                             onDismiss: { ReviewPrompt.askIfEarned(requestReview) }) { template in
                ActiveWorkoutView(template: template)
            }
        }
    }

    // MARK: Aujourd'hui

    /// Recalculé à chaque rendu, comme `progression` et `briefing`.
    private var today: TodayState {
        TodayState.make(templates: templates, sessions: sessions, runs: runs, races: races,
                        imported: importedActivities, signals: signals)
    }

    /// Change dès qu'une activité est ajoutée ou supprimée, et toutes les 3 h.
    private var forecastSignature: String {
        let slot = Calendar.current.component(.hour, from: .now) / 3
        return "\(sessions.count)-\(runs.count)-\(races.count)-\(templates.count)-"
            + "\(importedActivities.count)-\(signals?.adjustment ?? 99)-\(slot)-"
            + "\(morningBriefing)-\(briefingHour):\(briefingMinute)-\(focusRaw)"
    }

    /// Lit Apple Santé si la personne l'a activé : importe les entraînements
    /// de la montre et des autres apps, et relève sommeil et VFC.
    private func refreshHealth() async {
        guard healthImportEnabled else {
            signals = nil
            return
        }
        await HealthKitManager.shared.importWorkouts(context: context)
        signals = await HealthKitManager.shared.recoverySignals()
    }

    private func start(_ action: TodayPlan.Action) {
        showRecovery = false
        switch action {
        case .workout(let name):
            activeTemplate = templates.first { $0.name == name }
        case .hardRun, .easyRun:
            tabSelection.wrappedValue = 2
        case .rest:
            break
        }
    }

    /// Siri, Raccourcis ou widget : la séance conseillée, ou l'explication
    /// d'un jour de repos.
    private func startToday() {
        let action = today.plan.action
        if action == .rest {
            showRecovery = true
        } else {
            start(action)
        }
    }

    // MARK: Semaine allégée

    private var deloadEnd: Date? {
        guard deloadStart > 0 else { return nil }
        let end = Date(timeIntervalSince1970: deloadStart)
            .addingTimeInterval(Double(Deload.lengthDays) * 86_400)
        return end > .now ? end : nil
    }

    /// Sur les soixante dernières séances : assez pour un bloc de cinq
    /// semaines et pour repérer un plateau.
    private var deloadAdvice: Deload.Reason? {
        guard deloadEnd == nil, Date.now.timeIntervalSince1970 >= deloadSnooze else { return nil }
        let recent = sessions.prefix(60).map { session in
            Deload.summary(date: session.date,
                           sets: session.sets.map { (exercise: $0.exerciseName, reps: $0.reps, weight: $0.weight) })
        }
        return Deload.advice(sessions: recent,
                             lastDeload: deloadStart > 0 ? Date(timeIntervalSince1970: deloadStart) : nil,
                             now: .now)
    }

    @ViewBuilder
    private var deloadSection: some View {
        if let end = deloadEnd {
            DeloadActiveCard(end: end) {
                // Arrêtée plus tôt : elle compte quand même comme faite.
                deloadStart = Date.now
                    .addingTimeInterval(-Double(Deload.lengthDays) * 86_400).timeIntervalSince1970
            }
        } else if let advice = deloadAdvice {
            DeloadCard(reason: advice,
                       onStart: { deloadStart = Date.now.timeIntervalSince1970 },
                       onLater: {
                           deloadSnooze = Date.now
                               .addingTimeInterval(Double(Deload.lengthDays) * 86_400).timeIntervalSince1970
                       })
        }
    }

    // MARK: Partage de la semaine

    /// Le bouton n'apparaît que s'il y a quelque chose à montrer.
    private var hasActivityThisWeek: Bool {
        let since = Date.now.addingTimeInterval(-7 * 86_400)
        return [sessions.first?.date, runs.first?.date, races.first?.date]
            .contains { ($0 ?? .distantPast) >= since }
    }

    /// Calculé à l'ouverture de la feuille seulement : parcourir toutes les
    /// séries à chaque rendu de l'accueil serait du gaspillage.
    private var weekRecap: WeeklyRecap {
        WeeklyRecap.make(
            workouts: sessions.map { (date: $0.date, volumeKg: $0.totalVolume) },
            runs: runs.map { (date: $0.date, km: $0.distanceKm) },
            raceDates: races.map(\.date),
            sets: allSets.map { WeeklyRecap.LoggedSet(exercise: $0.exerciseName, reps: $0.reps,
                                                      weight: $0.weight, date: $0.date) },
            streakWeeks: weekly.weeks)
    }

    private var shareWeekButton: some View {
        Button {
            showRecap = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.brand)
                Text("Partager ma semaine")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Signature

    private var footerSignature: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.caption)
            Text("Une app DevShield")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: Fond dégradé (base du rendu "liquid glass")

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), Color.brand.opacity(0.12), Color(.systemGroupedBackground)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profileName.isEmpty ? greeting + " 👋" : "\(greeting), \(profileName) 👋")
                        .font(.largeTitle.weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    // le nombre de jours est déjà mis en avant dans la carte
                    // « streak » : ici on garde un encouragement sans le chiffre
                    Text(weekly.weeks > 0 || weekly.thisWeek > 0
                         ? String(localized: "Belle régularité, garde le rythme 🔥")
                         : InclusiveText.backAtItToday(UserSex(stored: profileSexRaw)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                // La mascotte occupe de l'espace HORIZONTAL libre : son coût
                // vertical est nul, ce qui préserve la remontée de la carte
                // Compléments au-dessus de la ligne de flottaison.
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                        showsCoach.toggle()
                    }
                } label: {
                    MascotView(mood: showsCoach ? .happy : .idle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Coach LiftRun")
            }

            if showsCoach {
                SpeechBubble(text: coachMessage)
                    .transition(.scale(scale: 0.9, anchor: .topTrailing)
                        .combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Recalculé à la volée, jamais stocké — même principe que `Progression`.
    private var briefing: CoachBriefing {
        CoachBriefing.make(sets: allSets, runs: runs, food: food,
                           maintenanceKcal: nil)
    }

    private var coachMessage: String {
        // Le bilan croisé prime : s'il a quelque chose de notable à dire, il est
        // plus utile qu'un encouragement générique.
        if let insight = MascotCoach.insight(briefing) { return insight }
        return MascotCoach.message(totalSessions: sessions.count,
                            weeksStreak: weekly.weeks,
                            sessionsThisWeek: sessionsThisWeek,
                            kmThisMonth: kmThisMonth)
    }

    /// Volume du mois : en tonnes au-delà de 1 000 kg, sinon en kilos.
    private var volumeText: String {
        volumeThisMonth >= 1000
            ? "\(oneDecimal(Double(volumeThisMonth) / 1000)) t"
            : "\(volumeThisMonth)"
    }

    /// Une décimale, séparateur selon la langue.
    ///
    /// `String(format:)` écrit toujours un point : « 23.5 t » au lieu de
    /// « 23,5 t » en français comme en espagnol.
    private func oneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    // MARK: Grille de stats

    @State private var statsAppeared = false
    @State private var showsCoach = false

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            GlassStatCard(icon: "flame.fill", tint: .orange,
                          value: "\(sessionsThisWeek)",
                          // accord au singulier : « 1 séances » se remarque
                          label: sessionsThisWeek > 1 ? "séances cette semaine"
                                                      : "séance cette semaine",
                          pulse: sessionsThisWeek > 0)
                .statEntrance(statsAppeared, index: 0)
            Button { showGoalSheet = true } label: {
                GlassStatCard(icon: "bolt.fill", tint: Color.brand,
                              value: "\(weekly.weeks)",
                              label: weekly.weeks > 1 ? "semaines d'objectif" : "semaine d'objectif",
                              pulse: weekly.isThisWeekDone,
                              progress: weekly.progress,
                              detail: "\(weekly.thisWeek)/\(weekly.goal)")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Modifier l'objectif de la semaine")
            .statEntrance(statsAppeared, index: 1)
            GlassStatCard(icon: "scalemass.fill", tint: .purple,
                          value: volumeText,
                          label: "volume ce mois (kg)")
                .statEntrance(statsAppeared, index: 2)
            GlassStatCard(icon: "figure.run", tint: .green,
                          value: oneDecimal(kmThisMonth), label: "km ce mois")
                .statEntrance(statsAppeared, index: 3)
        }
        .onAppear {
            guard !statsAppeared else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { statsAppeared = true }
        }
    }

    // MARK: Démarrage rapide

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Démarrer une séance")
                .font(.headline)
                .padding(.leading, 4)

            if templates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell")
                        .font(.title)
                        .foregroundStyle(Color.brand)
                    Text("Aucune séance type pour l'instant")
                        .font(.subheadline.weight(.medium))
                    Text("Crée ta première séance dans l'onglet Séances pour la lancer d'ici en un tap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .glassCard()
            }

            ForEach(templates) { template in
                Button {
                    activeTemplate = template
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: template.icon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(LinearGradient(colors: [Color.brand, .purple],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name).font(.headline).foregroundStyle(.primary)
                            Text(template.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.brand)
                    }
                    .padding(14)
                    .glassCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Dernière activité (séance ou course, la plus récente)

    @ViewBuilder
    private var recentActivitySection: some View {
        let lastSession = sessions.first
        let lastRun = runs.first
        // on prend la plus récente des deux, tous types confondus
        let sessionIsNewer = (lastSession?.date ?? .distantPast) >= (lastRun?.date ?? .distantPast)

        if let session = lastSession, sessionIsNewer {
            recentCard(title: "Dernière activité", icon: "checkmark.seal.fill", tint: .green,
                       name: session.templateName, date: session.date,
                       trailing: "\(session.sets.count) séries")
        } else if let run = lastRun {
            recentCard(title: "Dernière activité", icon: "figure.run", tint: .green,
                       name: String(format: String(localized: "Course · %.2f km"), run.distanceKm), date: run.date,
                       trailing: PaceFormatter.duration(run.durationSeconds))
        }
    }

    private func recentCard(title: String, icon: String, tint: Color,
                            name: String, date: Date, trailing: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.leading, 4)
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline.weight(.semibold))
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(trailing)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .glassCard()
        }
    }
}

// MARK: - Objectif de la semaine

private struct WeeklyGoalSheet: View {
    @Binding var goal: Int
    let activityDates: [Date]
    @Environment(\.dismiss) private var dismiss

    /// Recalculé avec l'objectif en cours de réglage : on voit tout de suite
    /// l'effet d'un changement sur la série.
    private var status: WeeklyStreak.Status {
        WeeklyStreak.status(activityDates: activityDates, goal: goal)
    }

    private var goalText: LocalizedStringKey {
        goal > 1 ? "\(goal) jours actifs par semaine" : "\(goal) jour actif par semaine"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $goal, in: WeeklyStreak.goalRange) {
                        Text(goalText)
                    }
                } footer: {
                    Text("Une séance et une course le même jour comptent pour un seul jour. Les jours de repos ne cassent rien : seule la semaine compte.")
                }
                Section("Cette semaine") {
                    LabeledContent("Jours actifs", value: "\(status.thisWeek) / \(status.goal)")
                    LabeledContent("Semaines d'affilée", value: "\(status.weeks)")
                }
            }
            .navigationTitle("Objectif de la semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Carte statistique en verre

private struct GlassStatCard: View {
    let icon: String
    let tint: Color
    let value: String
    /// `LocalizedStringKey` : les libellés fournis aux sites d'appel sont donc
    /// extraits automatiquement dans le String Catalog.
    let label: LocalizedStringKey
    var pulse: Bool = false
    /// Avancement (0…1) dessiné en anneau autour de l'icône, avec son détail
    /// chiffré à droite : aucune ligne en plus, la grille reste alignée.
    var progress: Double? = nil
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(progress == nil ? .title3 : .caption.weight(.bold))
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: pulse)
                    .frame(width: progress == nil ? nil : 26, height: progress == nil ? nil : 26)
                    .overlay {
                        if let progress {
                            Circle().stroke(tint.opacity(0.18), lineWidth: 3)
                            Circle().trim(from: 0, to: progress)
                                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                if let detail {
                    Spacer(minLength: 0)
                    Text(detail)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(value)
                // taille relative → suit les réglages d'accessibilité (Dynamic Type)
                .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        // 92 au lieu de 110 : gagne une trentaine de points sur la grille 2×2,
        // ce qui fait remonter la carte Compléments au-dessus de la ligne de
        // flottaison sans rendre les chiffres moins lisibles.
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(13)
        .glassCard()
    }
}

// Entrée en cascade des cartes de stats (scale + fondu décalés)
private extension View {
    func statEntrance(_ appeared: Bool, index: Int) -> some View {
        self
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.6)
                .delay(Double(index) * 0.08), value: appeared)
    }
}

// MARK: - Effet "liquid glass" réutilisable
// Base glassmorphism (Material) qui fonctionne sur iOS 17+.
// Sur iOS 26+, on applique en plus le vrai Liquid Glass (.glassEffect).

extension View {
    @ViewBuilder
    func glassCard() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
    }
}

// MARK: - Carte de niveau (gamification)

/// Niveau, XP et progression, en **une seule ligne**.
///
/// Volontairement compacte : la version précédente occupait près de 140 points
/// de hauteur et repoussait la carte Compléments sous la ligne de flottaison.
/// Le détail complet est à un tap, dans `ProgressionDetailView` — ici on ne garde
/// que le nécessaire pour donner envie d'y aller.
private struct LevelCard: View {
    let progression: Progression
    @State private var shownProgress: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Niveau \(progression.level)")
                        .font(.subheadline.weight(.bold))
                    Text(progression.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.brand.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(colors: [Color.brand, .purple],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * shownProgress))
                    }
                }
                .frame(height: 6)
            }

            Text("\(progression.totalXP) XP")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.brand)
                .contentTransition(.numericText())

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassCard()
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.25)) {
                shownProgress = progression.progress
            }
        }
    }
}
