import SwiftUI
import UIKit

// MARK: - Octobre Rose

/// Octobre Rose : pendant tout le mois d'octobre, l'accueil sensibilise au
/// dépistage du cancer du sein et le thème rose est offert à tout le monde.
/// L'icône au ruban rose, elle, reste au choix dans le profil toute l'année.
enum PinkOctober {
    /// Vrai du 1er au 31 octobre, en heure locale.
    static func isActive(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        #if DEBUG
        // Test à la main et captures d'écran : `-debugPinkOctober YES`. Ignoré sous
        // XCTest, sinon l'argument du schéma fausserait les tests sur les dates.
        if UserDefaults.standard.bool(forKey: "debugPinkOctober"), NSClassFromString("XCTestCase") == nil {
            return true
        }
        #endif
        return calendar.component(.month, from: date) == 10
    }

    /// Portail officiel de l'Institut national du cancer sur le dépistage.
    static let screeningURL = URL(string: "https://jefaismondepistage.cancer.fr/cancers-du-sein/")!

    /// Bandeau masqué, mémorisé par année : il revient l'octobre suivant.
    static func dismissedKey(on date: Date = .now, calendar: Calendar = .current) -> String {
        "pinkOctoberDismissed\(calendar.component(.year, from: date))"
    }

    /// Le rose du ruban (le même que sur l'icône et les visuels).
    static let ribbonPink = Color(red: 0.95, green: 0.33, blue: 0.59)
}

// MARK: - Icône de l'app

enum AppIconChoice: String, CaseIterable, Identifiable {
    case classic, pinkRibbon
    var id: String { rawValue }

    /// Jeu d'icônes de Assets.xcassets ; nil : l'icône principale.
    var iconName: String? { self == .classic ? nil : "AppIconRose" }

    /// Une icône d'app ne se charge pas comme une image : on garde un aperçu à part.
    var previewImage: String { self == .classic ? "AppIconPreview" : "AppIconRosePreview" }

    var label: String {
        switch self {
        case .classic: String(localized: "Classique")
        case .pinkRibbon: String(localized: "Octobre Rose")
        }
    }

    @MainActor static var current: AppIconChoice {
        UIApplication.shared.alternateIconName == nil ? .classic : .pinkRibbon
    }

    /// iOS confirme lui-même le changement par une alerte système.
    @MainActor func apply() async {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != iconName else { return }
        try? await UIApplication.shared.setAlternateIconName(iconName)
    }
}

// MARK: - Bandeau d'accueil

/// Un simple message de sensibilisation : le thème et l'icône roses se règlent dans le profil.
struct PinkOctoberCard: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image("PinkRibbon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 38)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Octobre Rose")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PinkOctober.ribbonPink)
                    Text("Ce mois-ci, LiftRun se met au rose pour la lutte contre le cancer du sein. Le dépistage sauve des vies : parles-en autour de toi.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Masquer")
            }
            Link(destination: PinkOctober.screeningURL) {
                Label("S'informer sur le dépistage", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(PinkOctober.ribbonPink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Choix de l'icône (profil)

struct AppIconPicker: View {
    @State private var current = AppIconChoice.current

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icône de l'app")
            HStack(spacing: 18) {
                ForEach(AppIconChoice.allCases) { choice in
                    let selected = current == choice
                    Button {
                        Task {
                            await choice.apply()
                            current = AppIconChoice.current
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(choice.previewImage)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.brand, lineWidth: selected ? 3 : 0)
                                        .padding(-4)
                                }
                            Text(choice.label)
                                .font(.caption2)
                                .foregroundStyle(selected ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
