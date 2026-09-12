import SwiftUI

// MARK: - Formats et ambiances

/// Story pour Instagram et WhatsApp, carré pour une publication.
enum RecapFormat: String, CaseIterable, Identifiable {
    case story, square

    var id: String { rawValue }

    var size: CGSize {
        self == .story ? CGSize(width: 360, height: 640) : CGSize(width: 360, height: 360)
    }

    var label: LocalizedStringKey { self == .story ? "Story" : "Carré" }
}

enum RecapTheme: String, CaseIterable, Identifiable {
    case indigo, ember, night

    var id: String { rawValue }

    @MainActor var colors: [Color] {
        switch self {
        case .indigo: [Color.brand, .purple, .pink]
        case .ember:  [Color(red: 1.0, green: 0.56, blue: 0.2),
                       Color(red: 0.93, green: 0.24, blue: 0.34),
                       Color(red: 0.52, green: 0.13, blue: 0.44)]
        case .night:  [Color(red: 0.06, green: 0.07, blue: 0.13),
                       Color(red: 0.14, green: 0.16, blue: 0.32)]
        }
    }

    /// Couleur des icônes posées sur les pastilles blanches de la frise.
    @MainActor var ink: Color {
        switch self {
        case .indigo, .night: Color.brand
        case .ember: Color(red: 0.86, green: 0.22, blue: 0.3)
        }
    }

    var name: LocalizedStringKey {
        switch self {
        case .indigo: "Indigo"
        case .ember:  "Braise"
        case .night:  "Nuit"
        }
    }
}

// MARK: - Carte « Ma semaine » à partager

/// Image des 7 derniers jours : muscu et course réunies sur une même carte,
/// ce qu'aucune autre app ne peut montrer.
///
/// Dessinée à taille fixe (rendue ×3 : 1080 × 1920 en story, 1080 × 1080 en
/// carré) : l'image partagée est identique quel que soit l'iPhone.
struct WeeklyRecapCard: View {
    let recap: WeeklyRecap
    var format: RecapFormat = .story
    var theme: RecapTheme = .indigo
    /// Prénom affiché au-dessus du titre, si la personne l'a choisi.
    var name: String? = nil

    private var isStory: Bool { format == .story }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: isStory ? 22 : 12)
            title
            Spacer(minLength: isStory ? 20 : 12)
            WeekStrip(days: recap.days, ink: theme.ink)
            Spacer(minLength: isStory ? 20 : 12)
            if isStory {
                VStack(spacing: 12) {
                    strengthBlock(compact: false)
                    runBlock(compact: false)
                }
                if recap.races > 0 || recap.streakWeeks > 0 {
                    Spacer(minLength: 14)
                    badges
                }
            } else {
                HStack(spacing: 10) {
                    strengthBlock(compact: true)
                    runBlock(compact: true)
                }
            }
            Spacer(minLength: 12)
            Text("Muscu + course, une seule app.")
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.9)
        }
        .padding(isStory ? 28 : 22)
        .frame(width: format.size.width, height: format.size.height, alignment: .topLeading)
        .foregroundStyle(.white)
        .background { background }
        .clipped()
    }

    // MARK: Parties

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LiftRun")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
            Spacer()
            Text(range)
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.85)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name, !name.isEmpty {
                Text(name.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .opacity(0.85)
            }
            Text("Ma semaine hybride")
                .font(.system(size: isStory ? 40 : 30, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }

    private func strengthBlock(compact: Bool) -> some View {
        StatBlock(kind: "Force", symbol: "dumbbell.fill",
                  value: recap.tonnes.formatted(.number.precision(.fractionLength(1))),
                  unit: "t", detail: strengthDetail,
                  highlight: compact ? nil : recordLine, compact: compact)
    }

    private func runBlock(compact: Bool) -> some View {
        StatBlock(kind: "Course", symbol: "figure.run",
                  value: recap.kilometres.formatted(.number.precision(.fractionLength(1))),
                  unit: "km", detail: runDetail, highlight: nil, compact: compact)
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: 8) {
            if recap.races > 0 { badge("flag.checkered", racesText) }
            if recap.streakWeeks > 0 { badge("bolt.fill", streakText) }
        }
    }

    private func badge(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.18), in: Capsule())
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            // Halo discret en haut à droite : donne du relief sans rien dire.
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 150, y: isStory ? -250 : -150)
        }
    }

    // MARK: Libellés (accordés au nombre)

    private var range: String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(recap.start.formatted(format)) – \(recap.end.formatted(format))"
    }

    private var strengthDetail: String {
        var parts: [String] = []
        switch recap.workouts {
        case 0: parts.append(String(localized: "aucune séance"))
        case 1: parts.append(String(localized: "1 séance"))
        default: parts.append(String(localized: "\(recap.workouts) séances"))
        }
        switch recap.personalRecords {
        case 0: break
        case 1: parts.append(String(localized: "1 record"))
        default: parts.append(String(localized: "\(recap.personalRecords) records"))
        }
        return parts.joined(separator: " · ")
    }

    private var runDetail: String {
        var parts: [String] = []
        switch recap.runs {
        case 0: parts.append(String(localized: "aucune sortie"))
        case 1: parts.append(String(localized: "1 sortie"))
        default: parts.append(String(localized: "\(recap.runs) sorties"))
        }
        if recap.runs > 1 {
            let longest = recap.longestRunKm.formatted(.number.precision(.fractionLength(1)))
            parts.append(String(localized: "plus longue \(longest) km"))
        }
        return parts.joined(separator: " · ")
    }

    /// Le record le plus marquant, cité par son nom : « Squat · 105 kg × 5 ».
    private var recordLine: String? {
        recap.topRecords.first.map { "\($0.exercise) · \($0.weight.localizedClean) kg × \($0.reps)" }
    }

    private var racesText: LocalizedStringKey {
        recap.races > 1 ? "\(recap.races) courses hybrides" : "1 course hybride"
    }

    private var streakText: LocalizedStringKey {
        recap.streakWeeks > 1 ? "\(recap.streakWeeks) semaines d'objectif d'affilée"
                              : "1 semaine d'objectif tenue"
    }
}

// MARK: - Bloc de chiffres

private struct StatBlock: View {
    let kind: LocalizedStringKey
    let symbol: String
    let value: String
    let unit: String
    let detail: String
    let highlight: String?
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Label(kind, systemImage: symbol)
                .font(.system(size: 12, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .opacity(0.85)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: compact ? 30 : 42, weight: .bold, design: .rounded).monospacedDigit())
                Text(unit)
                    .font(.system(size: compact ? 15 : 18, weight: .semibold))
                    .opacity(0.85)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(detail)
                .font(.system(size: 13, weight: .medium))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let highlight {
                Label(highlight, systemImage: "trophy.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 12 : 16)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Frise des 7 jours

/// La semaine d'un coup d'œil : une pastille par jour, avec ce qui y a été fait.
private struct WeekStrip: View {
    let days: [WeeklyRecap.Day]
    let ink: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(day.isActive ? Color.white : Color.white.opacity(0.14))
                        icon(for: day).foregroundStyle(ink)
                    }
                    .frame(width: 34, height: 34)
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func icon(for day: WeeklyRecap.Day) -> some View {
        if day.raced {
            Image(systemName: "flag.checkered").font(.system(size: 14, weight: .bold))
        } else if day.lifted && day.ran {
            VStack(spacing: 0) {
                Image(systemName: "dumbbell.fill")
                Image(systemName: "figure.run")
            }
            .font(.system(size: 9, weight: .bold))
        } else if day.lifted {
            Image(systemName: "dumbbell.fill").font(.system(size: 13, weight: .bold))
        } else if day.ran {
            Image(systemName: "figure.run").font(.system(size: 14, weight: .bold))
        }
    }
}

// MARK: - Feuille de partage

struct WeeklyRecapSheet: View {
    let recap: WeeklyRecap
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("recapFormat") private var formatRaw = RecapFormat.story.rawValue
    @AppStorage("recapTheme") private var themeRaw = RecapTheme.indigo.rawValue
    @AppStorage("recapShowName") private var showName = true
    /// Rendue à l'ouverture puis à chaque changement de format ou d'ambiance :
    /// `ImageRenderer` est coûteux, pas question de le relancer à chaque
    /// rafraîchissement de la vue.
    @State private var image: Image?

    private var format: RecapFormat { RecapFormat(rawValue: formatRaw) ?? .story }
    private var theme: RecapTheme { RecapTheme(rawValue: themeRaw) ?? .indigo }
    private var name: String? { showName && !profileName.isEmpty ? profileName : nil }
    private var previewScale: CGFloat { format == .story ? 0.78 : 0.88 }

    private var card: WeeklyRecapCard {
        WeeklyRecapCard(recap: recap, format: format, theme: theme, name: name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    card
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(previewScale)
                        .frame(width: format.size.width * previewScale,
                               height: format.size.height * previewScale)
                        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                        .accessibilityElement(children: .combine)

                    Picker("Format", selection: $formatRaw) {
                        ForEach(RecapFormat.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 14) {
                        ForEach(RecapTheme.allCases) { option in
                            Button {
                                themeRaw = option.rawValue
                            } label: {
                                Circle()
                                    .fill(LinearGradient(colors: option.colors,
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: themeRaw == option.rawValue ? 2.5 : 0)
                                            .padding(-5)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.name)
                            .accessibilityAddTraits(themeRaw == option.rawValue ? .isSelected : [])
                        }
                        Spacer()
                        if !profileName.isEmpty {
                            Toggle("Prénom", isOn: $showName)
                                .fixedSize()
                        }
                    }
                    .padding(.horizontal, 6)

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

                    Text("Story pour Instagram et WhatsApp, carré pour une publication ou le groupe de ta salle.")
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
            .task(id: "\(formatRaw)-\(themeRaw)-\(showName)") { image = render() }
        }
    }

    private func render() -> Image? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
