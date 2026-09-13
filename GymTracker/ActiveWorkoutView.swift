import SwiftUI
import SwiftData
import AudioToolbox

// MARK: - Série en cours de saisie (draft, non persisté avant la fin)

struct DraftSet: Identifiable {
    let id = UUID()
    let exerciseName: String
    let reps: Int
    let weight: Double
    /// Record battu par cette série : il disparaît avec elle si on l'annule.
    let record: PRResult?
}

// MARK: - Exercice du jour

/// Un exercice tel qu'il se déroule aujourd'hui : celui de la séance type,
/// éventuellement remplacé (machine prise), allégé ou resserré.
struct PlannedExercise: Identifiable {
    let id = UUID()
    let source: ExerciseTemplate
    var name: String
    var catalogID: String?
    var sets: Int
    var repRange: String
    var restSeconds: Int
    var notes: String

    init(_ exercise: ExerciseTemplate) {
        source = exercise
        name = exercise.name
        catalogID = exercise.catalogID
        sets = exercise.targetSets
        repRange = exercise.repRange
        restSeconds = exercise.restSeconds
        notes = exercise.notes
    }
}

private struct ComebackInfo {
    let days: Int
    let factor: Double
}

private struct UndoAction {
    let id = UUID()
    let message: String
    let restore: () -> Void
}

// MARK: - Séance active

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let template: WorkoutTemplate

    @Query(sort: \SetRecord.date, order: .reverse) private var history: [SetRecord]

    @State private var exercises: [PlannedExercise]
    @State private var loggedSets: [DraftSet] = []
    @State private var startDate = Date.now
    @State private var showCancelAlert = false
    @State private var showSaveError = false
    @State private var showCelebration = false
    @State private var prFlash: PRResult?
    @State private var sessionPRs: [PRResult] = []
    /// Séance enregistrée, pour y noter le ressenti choisi sur l'écran de fin.
    @State private var savedSession: WorkoutSession?
    @StateObject private var restTimer = RestTimerModel()
    /// « J'ai 30 minutes » : temps disponible, nil pour la séance complète.
    @State private var timeBudget: Int?
    @State private var swapping: PlannedExercise?
    @State private var undo: UndoAction?
    /// Semaine allégée en cours, lue à l'ouverture de la séance.
    @State private var isDeload = DeloadStore.isActive()

    init(template: WorkoutTemplate) {
        self.template = template
        _exercises = State(initialValue: template.sortedExercises.map(PlannedExercise.init))
        #if DEBUG
        // Captures d'écran automatisées : `-debugTimeBudget 30`.
        let minutes = UserDefaults.standard.integer(forKey: "debugTimeBudget")
        if minutes > 0 { _timeBudget = State(initialValue: minutes) }
        #endif
    }

    // MARK: Historique et objectifs

    /// Dernière série enregistrée pour cet exercice (dernière séance, dernière
    /// série de cette séance), pour pré-régler reps et poids.
    private func lastValues(for name: String) -> (reps: Int, weight: Double)? {
        history
            .filter { $0.exerciseName == name }
            .max { ($0.date, $0.setIndex) < ($1.date, $1.setIndex) }
            .map { ($0.reps, $0.weight) }
    }

    /// Séries de la dernière séance où l'exercice a été fait. Toutes les séries
    /// d'une séance portent la date de son début : c'est ce qui les regroupe.
    private func lastSessionSets(for name: String) -> [ProgressiveOverload.PastSet] {
        let records = history.filter { $0.exerciseName == name }
        guard let lastDate = records.map(\.date).max() else { return [] }
        return records.filter { $0.date == lastDate }
            .map { ProgressiveOverload.PastSet(reps: $0.reps, weight: $0.weight) }
    }

    /// Première séance après une pause de dix jours ou plus (voir `Comeback`).
    /// Une fois la séance enregistrée, ses séries datent de `startDate` : la
    /// bannière disparaît d'elle-même.
    private var comeback: ComebackInfo? {
        guard let last = history.first?.date, last < startDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: last, to: startDate).day ?? 0
        return Comeback.factor(daysOff: days).map { ComebackInfo(days: days, factor: $0) }
    }

    /// Objectif du jour : ce qui fait de la séance une progression, pas une
    /// simple répétition de la précédente. Allégé à la reprise et pendant une
    /// semaine allégée.
    private func target(for item: PlannedExercise) -> ProgressiveOverload.Target? {
        let sets = lastSessionSets(for: item.name)
        let topWeight = sets.map(\.weight).max() ?? 0
        let equipment = ExerciseCatalog.find(id: item.catalogID)?.equipment
        let range = ProgressiveOverload.parse(item.repRange)
        let increment = ProgressiveOverload.increment(equipment: equipment, weight: topWeight)
        if let comeback {
            return ProgressiveOverload.lighter(lastSession: sets, range: range, increment: increment,
                                               factor: comeback.factor, kind: .comeback)
        }
        if isDeload {
            return ProgressiveOverload.lighter(lastSession: sets, range: range, increment: increment,
                                               factor: Deload.weightFactor, kind: .deload)
        }
        return ProgressiveOverload.target(lastSession: sets, range: range, increment: increment)
    }

    // MARK: Plan du jour

    /// Les exercices du jour, après semaine allégée et séance express. Un
    /// exercice déjà commencé n'est jamais retiré.
    private var plan: (items: [PlannedExercise], dropped: [String]) {
        var items = exercises
        if isDeload, comeback == nil {
            for i in items.indices { items[i].sets = Deload.sets(items[i].sets) }
        }
        guard let minutes = timeBudget else { return (items, []) }
        let fitted = QuickSession.fit(
            items.map { QuickSession.Item(name: $0.name, sets: $0.sets, restSeconds: $0.restSeconds) },
            minutes: minutes)
        var result: [PlannedExercise] = []
        for item in items {
            if let kept = fitted.kept.first(where: { $0.name == item.name }) {
                var copy = item
                copy.sets = kept.sets
                copy.restSeconds = kept.restSeconds
                result.append(copy)
            } else if loggedSets.contains(where: { $0.exerciseName == item.name }) {
                result.append(item)
            }
        }
        let dropped = fitted.dropped.filter { name in !result.contains { $0.name == name } }
        return (result, dropped)
    }

    // Barre de progression de la séance
    private func sessionProgress(_ items: [PlannedExercise]) -> some View {
        let total = max(items.reduce(0) { $0 + $1.sets }, 1)
        let done = min(loggedSets.count, total)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progression").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(done) / \(total) séries")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(done), total: Double(total))
                .tint(Color.brand)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    @ViewBuilder
    private func banners(_ plan: (items: [PlannedExercise], dropped: [String])) -> some View {
        if let comeback {
            CoachBanner(icon: "arrow.uturn.backward.circle.fill", tint: .orange,
                        text: String(localized: "Reprise après \(comeback.days) jours : charges à \(Int((comeback.factor * 100).rounded())) % aujourd'hui. La force revient vite, les tendons ont besoin d'une semaine."))
        } else if isDeload {
            CoachBanner(icon: "leaf.fill", tint: .teal,
                        text: String(localized: "Semaine allégée : moitié moins de séries, charges à \(Int((Deload.weightFactor * 100).rounded())) %. Tu récupères, la progression repart la semaine prochaine."))
        }
        if timeBudget != nil {
            CoachBanner(icon: "timer", tint: Color.brand, text: expressText(plan),
                        actionTitle: "Revenir à la séance complète") {
                withAnimation { timeBudget = nil }
            }
        }
    }

    private func expressText(_ plan: (items: [PlannedExercise], dropped: [String])) -> String {
        let seconds = QuickSession.estimatedSeconds(
            plan.items.map { QuickSession.Item(name: $0.name, sets: $0.sets, restSeconds: $0.restSeconds) })
        let text = String(localized: "Séance express : environ \(seconds / 60) min, repos courts et séries resserrées.")
        guard !plan.dropped.isEmpty else { return text }
        return text + " " + String(localized: "Retirés aujourd'hui : \(plan.dropped.formatted(.list(type: .and))).")
    }

    var body: some View {
        let plan = self.plan
        return NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    sessionProgress(plan.items)
                    banners(plan)
                    ForEach(plan.items) { item in
                        let target = target(for: item)
                        let last = lastValues(for: item.name)
                        ExerciseLogCard(
                            item: item,
                            sets: loggedSets.filter { $0.exerciseName == item.name },
                            last: last,
                            target: target,
                            warmUp: WarmUp.steps(workingWeight: target?.weight ?? last?.weight ?? 0,
                                                 equipment: ExerciseCatalog.find(id: item.catalogID)?.equipment),
                            onLog: { reps, weight in logSet(item: item, reps: reps, weight: weight) },
                            onSwap: { swapping = item },
                            onDelete: deleteSet
                        )
                        // Nouvel objectif (reprise, séance express, remplacement) :
                        // la carte repart des nouvelles valeurs.
                        .id("\(item.id)-\(item.name)-\(target?.reps ?? 0)-\(target?.weight ?? 0)")
                    }
                }
                .padding()
                .padding(.bottom, (restTimer.isRunning ? 100 : 0) + (undo != nil ? 64 : 0) + 20)
                // Rebond des pastilles de séries et des coches à chaque validation
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: loggedSets.count)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler", role: .destructive) { showCancelAlert = true }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Temps disponible", selection: $timeBudget.animation()) {
                            Text("Séance complète").tag(Int?.none)
                            ForEach([45, 30, 20], id: \.self) { minutes in
                                Text("J'ai \(minutes) min").tag(Int?.some(minutes))
                            }
                        }
                    } label: {
                        Image(systemName: timeBudget == nil ? "timer" : "timer.circle.fill")
                    }
                    .accessibilityLabel("Temps disponible")

                    Button("Terminer") { finishWorkout() }
                        .fontWeight(.semibold)
                        .disabled(loggedSets.isEmpty)
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if let undo {
                        UndoToast(message: undo.message) {
                            undo.restore()
                            withAnimation(.spring(duration: 0.3)) { self.undo = nil }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if restTimer.isRunning {
                        RestTimerBar(timer: restTimer)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .animation(.spring(duration: 0.35), value: restTimer.isRunning)
            // Célébration de fin de séance (confettis + stats)
            .overlay {
                if showCelebration {
                    WorkoutCelebrationView(
                        setCount: loggedSets.count,
                        volume: loggedSets.reduce(0) { $0 + Double($1.reps) * $1.weight },
                        durationSeconds: Int(Date.now.timeIntervalSince(startDate)),
                        records: sessionPRs,
                        templateName: template.name,
                        date: startDate,
                        onEffort: { effort in
                            savedSession?.perceivedEffort = effort
                            context.saveLogging()
                        },
                        onContinue: { dismiss() }
                    )
                    .transition(.opacity)
                }
            }
            // Flash « Record ! » façon Duolingo
            .overlay {
                if let prFlash {
                    RecordFlashView(record: prFlash)
                        .id(prFlash.id)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .sheet(item: $swapping) { item in
                SwapExerciseSheet(
                    currentName: item.name,
                    alternatives: ExerciseSwap.alternatives(to: ExerciseCatalog.find(id: item.catalogID),
                                                            named: item.name, in: ExerciseCatalog.all),
                    templateName: template.name
                ) { exercise, permanent in
                    swap(item, to: exercise, permanent: permanent)
                }
            }
            .alert("Abandonner la séance ?", isPresented: $showCancelAlert) {
                Button("Continuer la séance", role: .cancel) {}
                Button("Abandonner", role: .destructive) {
                    restTimer.stop()   // coupe chrono, Live Activity et notification
                    dismiss()
                }
            } message: {
                Text("Les séries saisies ne seront pas enregistrées.")
            }
            .alert("Enregistrement impossible", isPresented: $showSaveError) {
                Button("Réessayer") { finishWorkout() }
                Button("Fermer", role: .cancel) {}
            } message: {
                Text("Ta séance n'a pas pu être sauvegardée. Vérifie l'espace de stockage puis réessaie.")
            }
        }
    }

    // MARK: Actions

    private func logSet(item: PlannedExercise, reps: Int, weight: Double) {
        // séries antérieures pour cet exercice (historique + séance en cours)
        let prior: [(reps: Int, weight: Double)] =
            history.filter { $0.exerciseName == item.name }.map { ($0.reps, $0.weight) }
            + loggedSets.filter { $0.exerciseName == item.name }.map { ($0.reps, $0.weight) }
        let record = PersonalRecords.check(exercise: item.name, reps: reps,
                                           weight: weight, prior: prior)
        let draft = DraftSet(exerciseName: item.name, reps: reps, weight: weight, record: record)
        loggedSets.append(draft)
        restTimer.start(seconds: item.restSeconds, exerciseName: item.name, workoutName: template.name)
        Feedback.setLogged()

        // Record personnel ? → flash animé + mémorisé pour la célébration
        if let record {
            sessionPRs.append(record)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { prFlash = record }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.3)) { prFlash = nil }
            }
        }

        // Un pouce qui ripe sur « Valider » ne demande pas de confirmation :
        // il s'annule.
        offerUndo(String(localized: "Série validée")) {
            remove(draft)
            restTimer.stop()
        }
    }

    private func remove(_ draft: DraftSet) {
        loggedSets.removeAll { $0.id == draft.id }
        if let record = draft.record {
            sessionPRs.removeAll { $0.id == record.id }
        }
    }

    private func deleteSet(_ draft: DraftSet) {
        guard let index = loggedSets.firstIndex(where: { $0.id == draft.id }) else { return }
        withAnimation { remove(draft) }
        offerUndo(String(localized: "Série supprimée")) {
            loggedSets.insert(draft, at: min(index, loggedSets.count))
            if let record = draft.record { sessionPRs.append(record) }
        }
    }

    /// « Série supprimée · Annuler » pendant quatre secondes.
    private func offerUndo(_ message: String, restore: @escaping () -> Void) {
        let action = UndoAction(message: message, restore: restore)
        withAnimation(.spring(duration: 0.3)) { undo = action }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if undo?.id == action.id {
                withAnimation(.easeOut(duration: 0.3)) { undo = nil }
            }
        }
    }

    /// Remplace un exercice pas encore commencé ; aussi dans la séance type si
    /// demandé.
    private func swap(_ item: PlannedExercise, to exercise: CatalogExercise, permanent: Bool) {
        guard let index = exercises.firstIndex(where: { $0.id == item.id }) else { return }
        exercises[index].name = exercise.displayName
        exercises[index].catalogID = exercise.id
        // Les notes décrivaient l'ancien exercice.
        exercises[index].notes = ""
        if permanent {
            item.source.name = exercise.displayName
            item.source.catalogID = exercise.id
            item.source.notes = ""
            context.saveLogging()
        }
    }

    private func finishWorkout() {
        let session = WorkoutSession(
            date: startDate,
            templateName: template.name,
            durationSeconds: Int(Date.now.timeIntervalSince(startDate))
        )
        context.insert(session)
        // Numérotation par exercice, recalculée ici : une série supprimée en
        // cours de séance ne laisse pas de trou.
        var indexes: [String: Int] = [:]
        for draft in loggedSets {
            indexes[draft.exerciseName, default: 0] += 1
            let record = SetRecord(exerciseName: draft.exerciseName,
                                   setIndex: indexes[draft.exerciseName] ?? 1,
                                   reps: draft.reps, weight: draft.weight, date: startDate)
            record.session = session
            context.insert(record)
        }
        // si l'enregistrement échoue, on prévient au lieu de fêter une séance perdue
        guard context.saveLogging() else {
            showSaveError = true
            return
        }
        restTimer.stop()   // coupe chrono de repos, Live Activity et notification
        undo = nil
        savedSession = session

        // Enregistre l'entraînement dans Apple Santé
        let duration = session.durationSeconds
        let weight = UserDefaults.standard.double(forKey: "profileWeightKg")
        let kcal = CalorieEstimator.workoutKcal(durationSeconds: duration,
                                                weightKg: weight > 0 ? weight : 70)
        Task {
            await HealthKitManager.shared.saveStrengthWorkout(
                start: startDate, durationSeconds: duration, kcal: kcal)
        }

        // Séance enregistrée : on retiendra de proposer la note au retour sur
        // l'écran d'accueil — jamais pendant la célébration.
        ReviewPrompt.workoutCompleted()

        withAnimation(.easeOut(duration: 0.3)) { showCelebration = true }
    }
}

// MARK: - Carte exercice avec saisie

private struct ExerciseLogCard: View {
    let item: PlannedExercise
    let sets: [DraftSet]
    let last: (reps: Int, weight: Double)?
    let target: ProgressiveOverload.Target?
    let warmUp: [WarmUp.Step]
    var onLog: (Int, Double) -> Void
    var onSwap: () -> Void
    var onDelete: (DraftSet) -> Void

    @State private var reps: Int
    @State private var weight: Double
    @State private var showNotes = false
    @State private var showAnimation = false
    @FocusState private var focus: Field?

    private enum Field { case reps, weight }

    init(item: PlannedExercise, sets: [DraftSet],
         last: (reps: Int, weight: Double)?, target: ProgressiveOverload.Target?,
         warmUp: [WarmUp.Step],
         onLog: @escaping (Int, Double) -> Void,
         onSwap: @escaping () -> Void,
         onDelete: @escaping (DraftSet) -> Void) {
        self.item = item
        self.sets = sets
        self.last = last
        self.target = target
        self.warmUp = warmUp
        self.onLog = onLog
        self.onSwap = onSwap
        self.onDelete = onDelete
        // pré-remplit avec l'objectif du jour, à défaut la dernière performance,
        // sinon des valeurs par défaut
        _reps = State(initialValue: target?.reps ?? last?.reps ?? 8)
        _weight = State(initialValue: target?.weight ?? last?.weight ?? 20)
    }

    private var catalogEx: CatalogExercise? { ExerciseCatalog.find(id: item.catalogID) }
    private var isDone: Bool { sets.count >= item.sets }

    /// « Échauffement : 20 kg × 10 · 40 kg × 8 · 57,5 kg × 5 »
    private var warmUpText: String {
        let steps = warmUp.map { "\($0.weight.localizedClean) kg × \($0.reps)" }.joined(separator: " · ")
        return String(localized: "Échauffement : \(steps)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.headline)
                    Text("Objectif : \(item.sets) × \(item.repRange) · repos \(item.restSeconds) s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let last {
                        Label(last.weight > 0
                              ? "Dernière : \(last.reps) × \(last.weight.localizedClean) kg"
                              : "Dernière : \(last.reps) reps",
                              systemImage: "clock.arrow.circlepath")
                            .font(.caption2)
                            .foregroundStyle(Color.brand)
                    }
                    if let target {
                        Label(targetText(target), systemImage: targetSymbol(target))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    if sets.isEmpty, !warmUp.isEmpty {
                        Label(warmUpText, systemImage: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
                // Machine prise : un équivalent, tant que l'exercice n'est pas commencé.
                Button {
                    onSwap()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(sets.isEmpty ? Color.brand : Color.secondary)
                }
                .disabled(!sets.isEmpty)
                .accessibilityLabel("Remplacer l'exercice")
                if catalogEx != nil {
                    Button {
                        showAnimation = true
                    } label: {
                        Image(systemName: "book.fill")
                            .foregroundStyle(Color.brand)
                    }
                    .accessibilityLabel("Voir l'exécution de l'exercice")
                }
                if !item.notes.isEmpty {
                    Button {
                        showNotes.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Afficher les notes")
                }
            }

            if showNotes {
                Text(item.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            }

            // Séries validées — appui long pour en supprimer une
            if !sets.isEmpty {
                HStack(spacing: 8) {
                    ForEach(sets) { s in
                        Text(s.weight > 0 ? "\(s.reps) × \(s.weight.localizedClean) kg" : "\(s.reps) reps")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.brand.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.brand)
                            .contextMenu {
                                Button("Supprimer la série", systemImage: "trash", role: .destructive) {
                                    onDelete(s)
                                }
                            }
                            .accessibilityHint("Appui long pour supprimer la série")
                    }
                }
            }

            // Saisie — les valeurs centrales sont tappables pour saisie clavier
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("REPS").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        stepButton("minus") { if reps > 1 { reps -= 1 } }
                            .accessibilityLabel("Une répétition de moins")
                        TextField("", value: $reps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .frame(minWidth: 44)
                            .focused($focus, equals: .reps)
                            .accessibilityLabel("Répétitions")
                        stepButton("plus") { reps += 1 }
                            .accessibilityLabel("Une répétition de plus")
                    }
                }

                VStack(spacing: 2) {
                    Text("POIDS (KG)").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        stepButton("minus") { if weight >= 1.25 { weight -= 1.25 } }
                            .accessibilityLabel("Moins 1,25 kilo")
                        TextField("", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .frame(minWidth: 56)
                            .focused($focus, equals: .weight)
                            .accessibilityLabel("Poids en kilos")
                        stepButton("plus") { weight += 1.25 }
                            .accessibilityLabel("Plus 1,25 kilo")
                    }
                }

                Spacer()

                Button {
                    focus = nil
                    onLog(max(reps, 0), max(weight, 0))
                } label: {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(isDone ? .green : Color.brand)
                .clipShape(Circle())
                .accessibilityLabel("Valider la série")
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focus = nil }
            }
        }
        .sheet(isPresented: $showAnimation) {
            if let catalogEx {
                NavigationStack {
                    ExerciseDetailView(exercise: catalogEx)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Fermer") { showAnimation = false }
                            }
                        }
                }
                .presentationDetents([.large])
            }
        }
    }

    private func targetSymbol(_ t: ProgressiveOverload.Target) -> String {
        switch t.kind {
        case .increaseWeight: "arrow.up.circle.fill"
        case .comeback, .deload: "leaf.fill"
        case .addRep, .consolidate: "scope"
        }
    }

    /// « Aujourd'hui : 6 × 82,5 kg (+2,5 kg) » — l'objectif et ce qui change
    /// depuis la dernière fois, en une ligne.
    private func targetText(_ t: ProgressiveOverload.Target) -> String {
        let timed = ProgressiveOverload.parse(item.repRange)?.isTimed == true
        let load = t.weight.localizedClean
        switch t.kind {
        case .comeback:
            if timed { return String(localized: "Reprise : \(t.reps) s") }
            if t.weight == 0 { return String(localized: "Reprise : \(t.reps) reps") }
            return String(localized: "Reprise : \(t.reps) × \(load) kg")
        case .deload:
            if timed { return String(localized: "Semaine allégée : \(t.reps) s") }
            if t.weight == 0 { return String(localized: "Semaine allégée : \(t.reps) reps") }
            return String(localized: "Semaine allégée : \(t.reps) × \(load) kg")
        default:
            break
        }
        if timed {
            return String(localized: "Aujourd'hui : \(t.reps) s (+5 s)")
        }
        if t.weight == 0 {
            return String(localized: "Aujourd'hui : \(t.reps) reps (+1 rep)")
        }
        switch t.kind {
        case .increaseWeight:
            let gain = (t.weight - t.previousWeight).localizedClean
            return String(localized: "Aujourd'hui : \(t.reps) × \(load) kg (+\(gain) kg)")
        case .addRep where t.reps > t.previousReps:
            return String(localized: "Aujourd'hui : \(t.reps) × \(load) kg (+1 rep)")
        case .addRep:
            return String(localized: "Aujourd'hui : \(t.reps) × \(load) kg sur toutes les séries")
        case .consolidate, .comeback, .deload:
            return String(localized: "Aujourd'hui : \(t.reps) × \(load) kg, on consolide")
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timer de repos

@MainActor
final class RestTimerModel: ObservableObject {
    @Published var remaining: Int = 0
    @Published var total: Int = 1
    @Published var isRunning = false

    private var timer: Timer?
    private var endDate = Date.now
    private var exerciseName = ""
    private var workoutName = ""

    func start(seconds: Int, exerciseName: String, workoutName: String) {
        stop()
        self.exerciseName = exerciseName
        self.workoutName = workoutName
        total = max(seconds, 1)
        remaining = seconds
        // le décompte s'appuie sur une date de fin : même référence que la
        // Dynamic Island, et toujours juste après un passage en arrière-plan
        endDate = Date.now.addingTimeInterval(TimeInterval(seconds))
        isRunning = true

        // Dynamic Island + écran verrouillé + notification de fin.
        // La permission notifications est demandée ici, au moment utile (1er repos),
        // plutôt qu'en bloc au lancement de l'app.
        NotificationManager.shared.requestAuthorization()
        LiveActivityManager.shared.startRest(exerciseName: exerciseName, workoutName: workoutName, seconds: seconds)
        NotificationManager.shared.scheduleRestEnd(after: seconds, exerciseName: exerciseName)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let left = Int(ceil(endDate.timeIntervalSinceNow))
        if left > 0 {
            remaining = left
        } else {
            remaining = 0
            // son + haptique seulement si la fin vient d'arriver
            // (pas de fanfare tardive au retour dans l'app)
            if endDate.timeIntervalSinceNow > -3 {
                Feedback.restFinished()
            }
            stop()
        }
    }

    func add(_ seconds: Int) {
        endDate = endDate.addingTimeInterval(TimeInterval(seconds))
        remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        total += seconds
        LiveActivityManager.shared.updateRest(exerciseName: exerciseName, endDate: endDate, totalSeconds: total)
        NotificationManager.shared.scheduleRestEnd(after: remaining, exerciseName: exerciseName)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        LiveActivityManager.shared.endRest()
        NotificationManager.shared.cancelRestEnd()
    }
}

private struct RestTimerBar: View {
    @ObservedObject var timer: RestTimerModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(timer.remaining) / CGFloat(timer.total))
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.remaining)
                Text("\(timer.remaining)")
                    .font(.subheadline.monospacedDigit().weight(.bold))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 1) {
                Text("Repos").font(.headline)
                Text("Prochaine série dans \(timer.remaining) s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("−15 s") { timer.add(-15) }
                .buttonStyle(.bordered)
                .font(.footnote.weight(.semibold))
                .disabled(timer.remaining <= 15)

            Button("+15 s") { timer.add(15) }
                .buttonStyle(.bordered)
                .font(.footnote.weight(.semibold))

            Button {
                timer.stop()
            } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand)
            .accessibilityLabel("Passer le repos")
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

// MARK: - Helpers

extension Double {
    /// "20" au lieu de "20.0", "22.5" conservé
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", self)
            : String(format: "%.2f", self).replacingOccurrences(of: ".00", with: "")
    }

    /// Même rendu que `clean`, avec le séparateur décimal de la langue
    /// (« 82,5 » en français). `clean` reste réservé à l'export CSV, où le
    /// point est obligatoire.
    var localizedClean: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}
