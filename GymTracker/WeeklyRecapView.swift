import SwiftUI

// MARK: - Carte « Ma semaine » à partager

/// Image 9:16 (format story) des 7 derniers jours : muscu et course réunies
/// sur une même carte, ce qu'aucune autre app ne peut montrer.
///
/// Dessinée à taille fixe (360 × 640 points, rendue ×3 soit 1080 × 1920
/// pixels) : l'image partagée est identique quel que soit l'iPhone.
struct WeeklyRecapCard: View {
    let recap: WeeklyRecap

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("LiftRun")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Spacer()
                Text(range)
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.85)
            }

            Spacer(minLength: 28)

            Text("Ma semaine hybride")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 24)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                stat("\(recap.workouts)", sessionsLabel, "dumbbell.fill")
                stat(recap.kilometres.formatted(.number.precision(.fractionLength(1))), "km", "figure.run")
                stat(recap.tonnes.formatted(.number.precision(.fractionLength(1))), tonnesLabel, "scalemass.fill")
                stat("\(recap.activeDays)", daysLabel, "calendar")
            }

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 10) {
                if recap.personalRecords > 0 {
                    badge("trophy.fill", recordsText)
                }
                if recap.races > 0 {
                    badge("flag.checkered", racesText)
                }
                if recap.streakWeeks > 0 {
                    badge("bolt.fill", streakText)
                }
            }

            Spacer()

            Text("Muscu + course, une seule app.")
                .font(.system(size: 15, weight: .semibold))
                .opacity(0.9)
        }
        .padding(30)
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [Color.brand, .purple, .pink],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    // MARK: Éléments

    private func stat(_ value: String, _ label: LocalizedStringKey, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            // Deux lignes réservées partout : « séances de muscu » passe sur
            // deux lignes, « km » non, et les tuiles doivent rester alignées.
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .opacity(0.85)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func badge(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.18), in: Capsule())
    }

    // MARK: Libellés (accordés au nombre)

    private var range: String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(recap.start.formatted(format)) – \(recap.end.formatted(format))"
    }

    private var sessionsLabel: LocalizedStringKey {
        recap.workouts > 1 ? "séances de muscu" : "séance de muscu"
    }
    private var tonnesLabel: LocalizedStringKey { "tonnes soulevées" }
    private var daysLabel: LocalizedStringKey {
        recap.activeDays > 1 ? "jours actifs" : "jour actif"
    }
    private var recordsText: LocalizedStringKey {
        recap.personalRecords > 1 ? "\(recap.personalRecords) records battus" : "1 record battu"
    }
    private var racesText: LocalizedStringKey {
        recap.races > 1 ? "\(recap.races) courses hybrides" : "1 course hybride"
    }
    private var streakText: LocalizedStringKey {
        recap.streakWeeks > 1 ? "\(recap.streakWeeks) semaines d'objectif d'affilée"
                              : "1 semaine d'objectif tenue"
    }
}

// MARK: - Feuille de partage

struct WeeklyRecapSheet: View {
    let recap: WeeklyRecap
    @Environment(\.dismiss) private var dismiss
    /// Rendue une seule fois à l'ouverture : `ImageRenderer` est coûteux, pas
    /// question de le relancer à chaque rafraîchissement de la vue.
    @State private var image: Image?

    private let previewScale: CGFloat = 0.78

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WeeklyRecapCard(recap: recap)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(previewScale)
                        .frame(width: WeeklyRecapCard.size.width * previewScale,
                               height: WeeklyRecapCard.size.height * previewScale)
                        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                        .accessibilityElement(children: .combine)

                    if let image {
                        ShareLink(item: image,
                                  preview: SharePreview(Text("Ma semaine LiftRun"), image: image)) {
                            Label("Partager", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brand)
                    }

                    Text("Au format story (9:16) : prête pour Instagram, WhatsApp ou le groupe de ta salle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ma semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task { image = render() }
        }
    }

    private func render() -> Image? {
        let renderer = ImageRenderer(content: WeeklyRecapCard(recap: recap))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
