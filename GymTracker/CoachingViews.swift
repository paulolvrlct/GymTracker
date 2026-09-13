import SwiftUI

// MARK: - Bannière de coaching

/// Une phrase de contexte en tête de séance : reprise, semaine allégée,
/// séance express.
struct CoachBanner: View {
    let icon: String
    let tint: Color
    let text: String
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Annuler en un geste

/// « Série supprimée · Annuler » : pas de demande de confirmation, un retour
/// en arrière possible pendant quelques secondes.
struct UndoToast: View {
    let message: String
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            Button("Annuler", action: onUndo)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }
}

// MARK: - Remplacer un exercice

struct SwapExerciseSheet: View {
    let currentName: String
    let alternatives: [CatalogExercise]
    let templateName: String
    var onPick: (CatalogExercise, _ permanent: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var permanent = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if alternatives.isEmpty {
                        Text("Aucun équivalent trouvé dans le catalogue pour cet exercice.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(alternatives) { exercise in
                        Button {
                            onPick(exercise, permanent)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ExerciseIllustration(exercise: exercise, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(exercise.equipmentLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("À la place de \(currentName)")
                } footer: {
                    Text("Mêmes muscles travaillés, en commençant par un autre matériel : il a plus de chances d'être libre.")
                }

                Section {
                    Toggle("Remplacer aussi dans « \(templateName) »", isOn: $permanent)
                } footer: {
                    Text("Sinon, le changement ne vaut que pour aujourd'hui.")
                }
            }
            .navigationTitle("Remplacer l'exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Semaine allégée

struct DeloadCard: View {
    let reason: Deload.Reason
    var onStart: () -> Void
    var onLater: () -> Void

    private var text: String {
        switch reason {
        case .longBlock(let weeks):
            String(localized: "\(weeks) semaines d'entraînement d'affilée. Une semaine avec moitié moins de séries et des charges un peu plus légères, et tu repars plus fort : c'est ce que font les coachs.")
        case .plateau(let count):
            String(localized: "\(count) exercices ne progressent plus depuis trois séances. Une semaine plus légère relance souvent la progression mieux qu'un effort de plus.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Semaine allégée conseillée", systemImage: "leaf.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.teal)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("C'est parti", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                Button("Plus tard", action: onLater)
                    .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct DeloadActiveCard: View {
    let end: Date
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.title3)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Semaine allégée en cours")
                    .font(.subheadline.weight(.semibold))
                Text("Jusqu'à \(end.formatted(.dateTime.weekday(.wide).day().month(.wide))) : moitié moins de séries, charges allégées.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Arrêter", action: onStop)
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Muscu, course ou les deux ?

/// Trois choix, avec ce que chacun change : utilisé au premier lancement et
/// dans le profil.
struct TrainingFocusPicker: View {
    @Binding var selection: String

    var body: some View {
        ForEach(TrainingFocus.allCases) { focus in
            Button {
                selection = focus.rawValue
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: focus.symbol)
                        .font(.title3)
                        .foregroundStyle(Color.brand)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(focus.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(focus.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selection == focus.rawValue {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brand)
                    }
                }
                .contentShape(Rectangle())
            }
            // Style neutre : dans un formulaire, le style par défaut teinte
            // tout le libellé de la couleur d'accent.
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection == focus.rawValue ? .isSelected : [])
        }
    }
}
