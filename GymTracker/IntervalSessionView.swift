import SwiftUI

// MARK: - Lecteur de séance fractionnée

/// Guide une séance de fractionné en alternant effort et récupération, avec un
/// bip à chaque transition.
///
/// Les bips sont **distinguables sans regarder l'écran**, ce qui est tout
/// l'intérêt : deux bips pour partir en effort, un seul pour la récupération,
/// trois à la fin. C'est le minimum pour courir un 30/30 sans fixer son
/// téléphone.
struct IntervalSessionView: View {
    let session: TrainingPlans.Session
    let vma: Double
    @ObservedObject var tracker: RunTracker

    @Environment(\.dismiss) private var dismiss

    private enum Phase { case intro, effort, recovery, done }

    @State private var phase: Phase = .intro
    @State private var currentRep = 1
    @State private var remaining = 0
    @State private var ticker: Timer?

    private var intervals: TrainingPlans.Session.Intervals? { session.intervals }

    var body: some View {
        ScrollView {
            switch phase {
            case .intro:             intro
            case .effort, .recovery: running
            case .done:              done
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stop() }
    }

    // MARK: Avant de partir

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let i = intervals {
                Text("\(i.reps) fractions").font(.title2.bold())
                    .frame(maxWidth: .infinity)

                PaceTargetCard(zone: session.zone, vma: vma)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Deux bips : départ de la fraction.")
                    Text("Un bip : récupération.")
                    Text("Trois bips : séance terminée.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("Échauffe-toi avant de lancer : le chrono démarre tout de suite.")
                    .font(.footnote).foregroundStyle(.orange)

                Button {
                    start()
                } label: {
                    Text("Lancer la séance").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
    }

    // MARK: Pendant

    private var running: some View {
        VStack(spacing: 24) {
            Text(phase == .effort ? "Effort" : "Récupération")
                .font(.headline)
                .foregroundStyle(phase == .effort ? .green : .secondary)

            Text(PaceFormatter.duration(remaining))
                .font(.system(size: 84, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())

            if let i = intervals {
                Text("Fraction \(currentRep) / \(i.reps)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if phase == .effort {
                PaceTargetCard(zone: session.zone, vma: vma)
            }

            LabeledContent("Allure actuelle") {
                Text(PaceFormatter.string(secPerKm: tracker.currentPaceSecPerKm))
                    .monospacedDigit()
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(role: .destructive) { stop(); dismiss() } label: {
                Text("Arrêter").frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }

    // MARK: Après

    private var done: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54)).foregroundStyle(.green)
            Text("Séance terminée").font(.title2.bold())
            Text("Distance : \(tracker.distanceMeters.formatted(.number.precision(.fractionLength(0)))) m")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Fermer") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    // MARK: Chronométrage

    private func start() {
        guard let i = intervals else { return }
        tracker.reset()
        tracker.start()
        currentRep = 1
        phase = .effort
        remaining = i.effortSeconds
        Feedback.cue(2)
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in tick() }
    }

    private func tick() {
        guard let i = intervals, remaining > 0 else { return }
        remaining -= 1
        guard remaining == 0 else { return }

        switch phase {
        case .effort:
            // Dernière fraction : pas de récupération inutile, on termine.
            if currentRep >= i.reps {
                finish()
            } else {
                phase = .recovery
                remaining = i.recoverySeconds
                Feedback.cue(1)
            }
        case .recovery:
            currentRep += 1
            phase = .effort
            remaining = i.effortSeconds
            Feedback.cue(2)
        case .intro, .done:
            break
        }
    }

    private func finish() {
        stop()
        Feedback.cue(3)
        phase = .done
    }

    private func stop() {
        ticker?.invalidate(); ticker = nil
        if tracker.isRunning { _ = tracker.finish() }
    }
}

// MARK: - Allure cible

/// Rappel de la fourchette visée, réutilisé pendant l'effort.
struct PaceTargetCard: View {
    let zone: RunningScience.Zone
    let vma: Double

    var body: some View {
        let range = RunningScience.paceRange(zone: zone, vma: vma)
        return VStack(spacing: 2) {
            Text(zone.label).font(.caption).foregroundStyle(.secondary)
            Text("\(PaceFormatter.string(secPerKm: Double(range.fast))) – \(PaceFormatter.string(secPerKm: Double(range.slow)))")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.green.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
