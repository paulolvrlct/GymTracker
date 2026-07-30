import SwiftUI

// MARK: - Plans d'entraînement

/// Choix de l'objectif puis lecture du plan, avec les allures de l'utilisateur.
///
/// Sans VMA mesurée, le plan perdrait tout son intérêt : on renvoie donc vers le
/// test plutôt que d'afficher un simple tableau de durées.
struct TrainingPlansView: View {
    @ObservedObject var tracker: RunTracker

    @State private var goal: TrainingPlans.Goal = .tenK
    @State private var showVMATest = false

    var body: some View {
        List {
            if let vma = VMAStore.value {
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
