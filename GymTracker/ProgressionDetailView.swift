import SwiftUI

// MARK: - Détail du système de points

/// Explique le barème **avec les chiffres de l'utilisateur** plutôt qu'en
/// paraphrasant les règles : on voit exactement d'où vient chaque point, ce qui
/// rend le système crédible et donne envie de le faire monter.
struct ProgressionDetailView: View {
    let progression: Progression
    /// Paliers hybrides (voir `Milestones`), calculés par l'accueil.
    var milestones: [MilestoneStatus] = []

    /// Franchis d'abord, du plus récent au plus ancien, puis les autres, du
    /// plus avancé au moins avancé : ce qui est à portée de main en premier.
    private var sortedMilestones: [MilestoneStatus] {
        let achieved = milestones.filter(\.isAchieved)
            .sorted { ($0.achievedOn ?? .distantPast) > ($1.achievedOn ?? .distantPast) }
        let pending = milestones.filter { !$0.isAchieved }.sorted { $0.progress > $1.progress }
        return achieved + pending
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Niveau \(progression.level)")
                            .font(.title2.weight(.bold))
                        Spacer()
                        Text("\(progression.totalXP) XP")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color.brand)
                    }
                    Text(progression.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: progression.progress)
                        .tint(Color.brand)
                    Text("\(progression.xpAtCurrentLevel) / \(progression.xpForThisLevel) XP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            if !milestones.isEmpty {
                Section {
                    ForEach(sortedMilestones) { status in
                        MilestoneRow(status: status)
                    }
                } header: {
                    Text("Paliers hybrides · \(milestones.filter(\.isAchieved).count)/\(milestones.count)")
                } footer: {
                    Text("Muscu et course comptent ensemble : certains paliers ne se franchissent qu'en faisant les deux.")
                }
            }

            Section {
                sourceRow("Séances",
                          detail: "\(progression.workoutCount) × \(Progression.perWorkout) XP",
                          xp: progression.workoutXP)
                sourceRow("Volume soulevé",
                          detail: "\(decimal(progression.tonnesLifted)) t × \(Progression.perTonneLifted) XP",
                          xp: progression.volumeXP)
                sourceRow("Courses",
                          detail: "\(decimal(progression.kilometresRun)) km × \(Progression.perKilometre) XP",
                          xp: progression.runXP)
                sourceRow("Compléments",
                          detail: "\(progression.supplementCount) × \(Progression.perSupplementIntake) XP",
                          xp: progression.supplementXP)
            } header: {
                Text("D'où viennent tes points")
            } footer: {
                Text("Tes points sont recalculés depuis ton historique. Ils restent donc justes, même si tu supprimes une séance.")
            }

            Section("Paliers") {
                ForEach(progression.nearbyLevels, id: \.self) { lvl in
                    let reached = lvl <= progression.level
                    HStack {
                        Text("Niveau \(lvl)")
                            .fontWeight(lvl == progression.level ? .semibold : .regular)
                        Spacer()
                        Text("\(Progression.xpRequired(forLevel: lvl)) XP")
                            .font(.subheadline.monospacedDigit())
                            // tout en `Color` : mélanger `Color.brand` et les
                            // styles hiérarchiques (.secondary) dans un ternaire
                            // ne compile pas, les types diffèrent
                            .foregroundStyle(lvl == progression.level
                                             ? Color.brand
                                             : (reached ? Color.secondary
                                                        : Color.secondary.opacity(0.5)))
                    }
                }
            }
        }
        .navigationTitle("Comment ça marche")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Une décimale, séparateur selon la langue (virgule en FR/ES, point en EN).
    private func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private func sourceRow(_ label: LocalizedStringKey, detail: String, xp: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(xp) XP")
                .font(.subheadline.weight(.medium).monospacedDigit())
        }
    }
}

// MARK: - Palier

private struct MilestoneRow: View {
    let status: MilestoneStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.milestone.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status.isAchieved ? Color.white : Color.secondary)
                .frame(width: 36, height: 36)
                .background(status.isAchieved
                            ? AnyShapeStyle(LinearGradient(colors: [Color.brand, .purple],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color(.tertiarySystemFill)),
                            in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(status.milestone.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status.isAchieved ? .primary : .secondary)
                if status.milestone == .goalWeeks4, status.isAchieved {
                    // Palier « en cours » : la série court toujours, pas de date figée.
                    Text("Série en cours").font(.caption).foregroundStyle(.secondary)
                } else if let date = status.achievedOn {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(status.milestone.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: status.progress)
                        .tint(Color.brand)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
