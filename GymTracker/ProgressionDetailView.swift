import SwiftUI

// MARK: - Détail du système de points

/// Explique le barème **avec les chiffres de l'utilisateur** plutôt qu'en
/// paraphrasant les règles : on voit exactement d'où vient chaque point, ce qui
/// rend le système crédible et donne envie de le faire monter.
struct ProgressionDetailView: View {
    let progression: Progression

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
