import SwiftUI

// MARK: - Test de VMA (demi-Cooper, 6 minutes)

/// Trois temps : explication du protocole, test chronométré, résultat.
///
/// Le protocole est expliqué *avant* de lancer quoi que ce soit : un test mal
/// exécuté (départ trop rapide, pas d'échauffement) donne une valeur fausse, et
/// toutes les allures d'entraînement en découlent.
struct VMATestView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tracker: RunTracker

    private enum Phase { case intro, running, result }

    @State private var phase: Phase = .intro
    @State private var remaining = RunningScience.testDuration
    @State private var ticker: Timer?
    @State private var measuredDistance: Double = 0
    @State private var oneMinuteWarningDone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                switch phase {
                case .intro:   intro
                case .running: running
                case .result:  result
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Test de VMA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { stopAndClose() }
                }
            }
        }
        .interactiveDismissDisabled(phase == .running)
    }

    // MARK: Explication

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "stopwatch")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)

            Text("Cours la plus grande distance possible en 6 minutes, à allure la plus régulière possible.")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                bullet("Échauffe-toi 15 à 20 minutes avant, sinon le résultat sera sous-évalué.")
                bullet("Pars à une allure que tu penses pouvoir tenir 6 minutes : partir trop vite fausse tout le test.")
                bullet("Un bip au départ, un bip à 1 minute de la fin, trois bips à l'arrivée.")
                bullet("Reste en extérieur, GPS dégagé : c'est lui qui mesure la distance.")
            }

            if let vma = VMAStore.value, let date = VMAStore.testDate {
                Divider()
                LabeledContent("Ta VMA actuelle") {
                    Text(vmaText(vma)).font(.headline).foregroundStyle(.green)
                }
                Text("Mesurée le \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Button {
                startTest()
            } label: {
                Text(VMAStore.value == nil ? "Commencer le test" : "Refaire le test")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            if tracker.authorizationDenied {
                Text("Localisation refusée : active-la dans Réglages pour le suivi GPS.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding()
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 6)
            Text(text).font(.subheadline)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: Test en cours

    private var running: some View {
        VStack(spacing: 28) {
            Text(PaceFormatter.duration(remaining))
                .font(.system(size: 76, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())

            VStack(spacing: 4) {
                Text(tracker.distanceMeters.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                Text("mètres parcourus")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            ProgressView(value: Double(RunningScience.testDuration - remaining),
                         total: Double(RunningScience.testDuration))
                .tint(.green)

            Text("Tiens ton allure jusqu'au bout.")
                .font(.footnote).foregroundStyle(.secondary)

            Button(role: .destructive) { stopAndClose() } label: {
                Text("Abandonner le test").frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .padding(28)
    }

    // MARK: Résultat

    private var result: some View {
        let vma = RunningScience.vma(fromTestDistanceMeters: measuredDistance)
        let credible = RunningScience.plausibleRange.contains(vma)

        return VStack(alignment: .leading, spacing: 18) {
            if credible {
                VStack(spacing: 6) {
                    Text("Test terminé").font(.title2.bold())
                    Text(vmaText(vma))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("Distance parcourue : \(Int(measuredDistance)) m")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                PaceTableView(vma: vma)

                Button {
                    VMAStore.save(vma)
                    dismiss()
                } label: {
                    Text("Enregistrer ma VMA")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Test inexploitable").font(.title3.bold())
                    Text("Le GPS n'a mesuré que \(Int(measuredDistance)) m, ce qui ne donne pas un résultat crédible. Réessaie en extérieur, avec un signal stable.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Réessayer") { phase = .intro; remaining = RunningScience.testDuration }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }

    private func vmaText(_ vma: Double) -> String {
        "\(vma.formatted(.number.precision(.fractionLength(1)))) km/h"
    }

    // MARK: Chronométrage

    private func startTest() {
        remaining = RunningScience.testDuration
        oneMinuteWarningDone = false
        tracker.reset()
        tracker.start()
        phase = .running
        Feedback.cue()          // départ

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard remaining > 0 else { return }
            remaining -= 1

            if remaining == 60, !oneMinuteWarningDone {
                oneMinuteWarningDone = true
                Feedback.cue()          // dernière minute
            }
            if remaining == 0 { finishTest() }
        }
    }

    private func finishTest() {
        ticker?.invalidate(); ticker = nil
        measuredDistance = tracker.distanceMeters
        _ = tracker.finish()
        Feedback.cue(3)         // arrivée
        phase = .result
    }

    private func stopAndClose() {
        ticker?.invalidate(); ticker = nil
        if phase == .running { _ = tracker.finish() }
        dismiss()
    }
}

// MARK: - Tableau des allures

/// Les allures d'entraînement déduites d'une VMA.
struct PaceTableView: View {
    let vma: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mes allures d'entraînement").font(.headline)

            ForEach(RunningScience.Zone.allCases) { zone in
                let range = RunningScience.paceRange(zone: zone, vma: vma)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(zone.label).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(PaceFormatter.string(secPerKm: Double(range.fast))) – \(PaceFormatter.string(secPerKm: Double(range.slow)))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                    Text(zone.detail).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if zone != RunningScience.Zone.allCases.last { Divider() }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
