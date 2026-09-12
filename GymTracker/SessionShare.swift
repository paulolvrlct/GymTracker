import SwiftUI
import SwiftData

// MARK: - Ressenti de fin de séance

/// « Comment c'était ? » en une touche.
///
/// Cinq niveaux plutôt qu'une échelle de 1 à 10 : en fin de séance, on sait
/// dire « dur » ou « très dur », pas choisir entre 7 et 8. Les niveaux
/// correspondent à l'échelle d'effort perçu (3, 5, 7, 9, 10), que le moteur de
/// récupération utilise pour pondérer la charge.
struct EffortPicker: View {
    var onSelect: (Int) -> Void
    @State private var selected: Int?

    private let levels: [(value: Int, label: LocalizedStringKey)] = [
        (3, "Facile"), (5, "Modéré"), (7, "Dur"), (9, "Très dur"), (10, "Max"),
    ]

    private var prompt: LocalizedStringKey {
        selected == nil ? "Comment c'était ?" : "Noté : la forme du jour en tient compte."
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(prompt)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(levels, id: \.value) { level in
                    Button {
                        selected = level.value
                        onSelect(level.value)
                    } label: {
                        Text(level.label)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(selected == level.value ? Color.white : Color.primary)
                            .background(selected == level.value ? Color.brand : Color(.tertiarySystemFill),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == level.value ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Bouton de partage d'une image

/// Rend une carte en image (×3) à l'affichage, puis la propose au partage.
struct ShareImageButton<Card: View>: View {
    let title: LocalizedStringKey
    let card: Card
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(Text("LiftRun"), image: image)) {
                    Label(title, systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                ProgressView()
            }
        }
        .frame(minHeight: 28)
        .task {
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            image = renderer.uiImage.map { Image(uiImage: $0) }
        }
    }
}

// MARK: - Carte d'une séance

/// Story 9:16 d'une séance terminée : le moment où l'on est fier, et celui où
/// l'on partage.
struct WorkoutShareCard: View {
    let name: String
    let date: Date
    let setCount: Int
    let volumeKg: Double
    let durationSeconds: Int
    let records: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShareCardHeader(date: date)
            Spacer(minLength: 26)
            ShareCardEyebrow(text: "Muscu", symbol: "dumbbell.fill")
            Text(name)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 22)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(volumeValue)
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                Text(volumeUnit)
                    .font(.system(size: 24, weight: .semibold))
                    .opacity(0.85)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text("volume")
                .font(.system(size: 14, weight: .medium))
                .opacity(0.85)
            Spacer(minLength: 18)
            HStack(spacing: 10) {
                ShareTile(value: "\(setCount)", label: "séries")
                ShareTile(value: PaceFormatter.duration(durationSeconds), label: "durée")
            }
            if !records.isEmpty {
                Spacer(minLength: 16)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(records.prefix(3), id: \.self) { record in
                        Label(record, systemImage: "trophy.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                }
            }
            Spacer(minLength: 12)
            ShareCardFooter()
        }
        .padding(28)
        .frame(width: 360, height: 640, alignment: .topLeading)
        .foregroundStyle(.white)
        .background { ShareCardBackground(colors: [Color.brand, .purple, .pink]) }
        .clipped()
    }

    private var volumeValue: String {
        volumeKg >= 1000
            ? (volumeKg / 1000).formatted(.number.precision(.fractionLength(1)))
            : "\(Int(volumeKg))"
    }

    private var volumeUnit: String { volumeKg >= 1000 ? "t" : "kg" }
}

// MARK: - Carte d'une course

/// Story 9:16 d'une course : la distance, le tracé et l'allure.
struct RunShareCard: View {
    let run: RunSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShareCardHeader(date: run.date)
            Spacer(minLength: 26)
            ShareCardEyebrow(text: "Course", symbol: "figure.run")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(run.distanceKm.formatted(.number.precision(.fractionLength(2))))
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                Text("km")
                    .font(.system(size: 24, weight: .semibold))
                    .opacity(0.85)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 18)
            if run.routePoints.count > 1 {
                RoutePathShape(points: run.routePoints)
                    .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .padding(16)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Spacer(minLength: 18)
            }
            HStack(spacing: 10) {
                ShareTile(value: PaceFormatter.string(secPerKm: run.averagePaceSecPerKm), label: "allure")
                ShareTile(value: PaceFormatter.duration(run.durationSeconds), label: "durée")
            }
            Spacer(minLength: 12)
            ShareCardFooter()
        }
        .padding(28)
        .frame(width: 360, height: 640, alignment: .topLeading)
        .foregroundStyle(.white)
        .background {
            ShareCardBackground(colors: [Color(red: 0.07, green: 0.62, blue: 0.42),
                                         .teal,
                                         Color(red: 0.1, green: 0.32, blue: 0.58)])
        }
        .clipped()
    }
}

// MARK: - Éléments communs des cartes

private struct ShareCardHeader: View {
    let date: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LiftRun")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
            Spacer()
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.85)
        }
    }
}

private struct ShareCardEyebrow: View {
    let text: LocalizedStringKey
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .bold))
            .textCase(.uppercase)
            .tracking(1.4)
            .opacity(0.85)
            .padding(.bottom, 4)
    }
}

private struct ShareTile: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ShareCardFooter: View {
    var body: some View {
        Text("Muscu + course, une seule app.")
            .font(.system(size: 13, weight: .semibold))
            .opacity(0.9)
    }
}

private struct ShareCardBackground: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 150, y: -250)
        }
    }
}

#if DEBUG
// MARK: - Aperçu pour les captures (Debug uniquement)

/// Les deux cartes côte à côte, avec la dernière séance et la dernière
/// course, sans avoir à terminer une séance à la main
/// (`-debugOpenShareCards YES`).
struct ShareCardsPreview: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \RunSession.date, order: .reverse) private var runs: [RunSession]

    var body: some View {
        HStack(spacing: 12) {
            if let session = sessions.first {
                WorkoutShareCard(name: session.templateName, date: session.date,
                                 setCount: session.sets.count, volumeKg: session.totalVolume,
                                 durationSeconds: session.durationSeconds,
                                 records: ["Curl barre EZ — 24.5 kg (+2.5)"])
                    .scaleEffect(0.5)
                    .frame(width: 180, height: 320)
            }
            if let run = runs.first {
                RunShareCard(run: run)
                    .scaleEffect(0.5)
                    .frame(width: 180, height: 320)
            }
        }
        .padding()
    }
}
#endif
