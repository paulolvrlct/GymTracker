import SwiftUI

// MARK: - Plans d'entraînement

/// Choix de l'objectif puis lecture du plan, avec les allures de l'utilisateur.
///
/// Sans VMA mesurée, le plan perdrait tout son intérêt : on renvoie donc vers le
/// test plutôt que d'afficher un simple tableau de durées.
struct TrainingPlansView: View {
    @ObservedObject var tracker: RunTracker
    @ObservedObject private var premium = PremiumStore.shared

    private enum PlanKind { case run, hybrid }

    @State private var planKind: PlanKind
    @State private var goal: TrainingPlans.Goal = .tenK
    @State private var showVMATest = false
    @State private var showPaywall = false
    @State private var showHybridRace = false

    init(tracker: RunTracker, startWithHybrid: Bool = false) {
        _tracker = ObservedObject(wrappedValue: tracker)
        _planKind = State(initialValue: startWithHybrid ? .hybrid : .run)
    }

    var body: some View {
        List {
            Section {
                Picker("Type de plan", selection: $planKind) {
                    Text("Course").tag(PlanKind.run)
                    Text("Hybride").tag(PlanKind.hybrid)
                }
                .pickerStyle(.segmented)
            }

            if planKind == .hybrid {
                hybridPlanContent
            } else if let vma = VMAStore.value {
                Section {
                    Picker("Objectif", selection: $goal) {
                        ForEach(TrainingPlans.Goal.allCases) { g in
                            Text(g.label).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Ta VMA") {
                        Text("\(vma.formatted(.number.precision(.fractionLength(1)))) km/h")
                            .foregroundStyle(.green)
                    }
                    Text("\(goal.weekCount) semaines · \(TrainingPlans.sessionsPerWeek) séances par semaine")
                        .font(.caption).foregroundStyle(.secondary)
                }

                ForEach(TrainingPlans.weeks(for: goal)) { week in
                    Section {
                        ForEach(week.sessions) { session in
                            sessionCell(session, vma: vma)
                        }
                    } header: {
                        Text("Semaine \(week.number) · \(week.phase.label)")
                    } footer: {
                        // le conseil n'apparaît qu'au changement de phase, pour ne
                        // pas répéter le même texte dix fois
                        if isFirstWeekOfPhase(week, in: goal) {
                            Text(week.phase.advice)
                        }
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mesure d'abord ta VMA").font(.headline)
                        Text("Les plans affichent tes allures cibles, calculées depuis ta VMA. Sans elle, il ne resterait qu'un tableau de durées.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Passer le test de VMA") { showVMATest = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Plans d'entraînement")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showVMATest) { VMATestView(tracker: tracker) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .fullScreenCover(isPresented: $showHybridRace) { HybridRaceView() }
    }

    // MARK: Plan hybride (Premium)

    @ViewBuilder
    private var hybridPlanContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Préparer une course hybride").font(.headline)
                Text("8 semaines · 4 séances par semaine : muscu, fractionné, ateliers et enchaînements, dans un ordre qui protège tes jambes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if VMAStore.value == nil {
                    Text("Mesure ta VMA (onglet Course › Demi-fond) pour obtenir les allures du fractionné.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        }

        let weeks = HybridPlan.weeks()
        if premium.isPremium {
            ForEach(weeks) { week in
                Section {
                    ForEach(week.sessions) { session in
                        hybridSessionCell(session)
                    }
                } header: {
                    Text("Semaine \(week.number) · \(week.phase.label)")
                } footer: {
                    if week.number == 1 {
                        Text("Jamais de séance lourde pour les jambes la veille d'un fractionné ou d'un enchaînement.")
                    }
                }
            }
        } else if let first = weeks.first {
            // Aperçu gratuit de la première semaine : on juge le plan sur pièce.
            Section {
                ForEach(first.sessions) { session in
                    hybridSessionRow(session)
                }
                Button {
                    showPaywall = true
                } label: {
                    Label("Débloquer les 8 semaines (Premium)", systemImage: "lock.open.fill")
                }
            } header: {
                Text("Semaine 1 · aperçu")
            }
        }
    }

    /// Le fractionné mène au lecteur guidé, les enchaînements chronométrés au
    /// simulateur de course hybride.
    @ViewBuilder
    private func hybridSessionCell(_ session: HybridPlan.Session) -> some View {
        if let run = session.run, run.intervals != nil, let vma = VMAStore.value {
            NavigationLink {
                IntervalSessionView(session: run, vma: vma, tracker: tracker)
            } label: {
                hybridSessionRow(session)
            }
        } else if session.opensRaceSimulator {
            Button {
                showHybridRace = true
            } label: {
                hybridSessionRow(session)
            }
            .buttonStyle(.plain)
        } else {
            hybridSessionRow(session)
        }
    }

    private func hybridSessionRow(_ session: HybridPlan.Session) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(weekdayName(session.day))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(session.minutes) min")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Label(session.title, systemImage: symbol(for: session.kind))
                .font(.subheadline.weight(.medium))
            Text(session.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let intervals = session.run?.intervals {
                Text(structure(intervals))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
            }
            if session.opensRaceSimulator {
                Label("Ouvrir le simulateur", systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    /// 1 = lundi … 7 = dimanche (les symboles du calendrier commencent au dimanche).
    private func weekdayName(_ day: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        return symbols[day % 7]
    }

    private func symbol(for kind: HybridPlan.Session.Kind) -> String {
        switch kind {
        case .upperStrength:   "figure.strengthtraining.traditional"
        case .runQuality:      "bolt.fill"
        case .legsAndStations: "figure.strengthtraining.functional"
        case .hybrid:          "flag.checkered"
        }
    }

    private func isFirstWeekOfPhase(_ week: TrainingPlans.Week,
                                    in goal: TrainingPlans.Goal) -> Bool {
        week.number == 1
            || TrainingPlans.phase(week: week.number - 1, of: goal.weekCount) != week.phase
    }

    /// Les séances de fractionné mènent au lecteur guidé ; les séances continues
    /// restent une simple ligne d'information.
    @ViewBuilder
    private func sessionCell(_ session: TrainingPlans.Session, vma: Double) -> some View {
        if session.intervals != nil {
            NavigationLink {
                IntervalSessionView(session: session, vma: vma, tracker: tracker)
            } label: {
                sessionRow(session, vma: vma)
            }
        } else {
            sessionRow(session, vma: vma)
        }
    }

    private func sessionRow(_ session: TrainingPlans.Session, vma: Double) -> some View {
        let range = RunningScience.paceRange(zone: session.zone, vma: vma)
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.kind.label).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(session.minutes) min")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let intervals = session.intervals {
                Text(structure(intervals))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text(session.zone.label)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.15), in: Capsule())
                Text("\(PaceFormatter.string(secPerKm: Double(range.fast))) – \(PaceFormatter.string(secPerKm: Double(range.slow)))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    /// « 8 × 30 s / 30 s récup » ou « 3 × 10 min / 3 min récup ».
    private func structure(_ i: TrainingPlans.Session.Intervals) -> String {
        func unit(_ seconds: Int) -> String {
            seconds >= 60 ? String(localized: "\(seconds / 60) min")
                          : String(localized: "\(seconds) s")
        }
        return String(localized: "\(i.reps) × \(unit(i.effortSeconds)) / \(unit(i.recoverySeconds)) récup")
    }
}
