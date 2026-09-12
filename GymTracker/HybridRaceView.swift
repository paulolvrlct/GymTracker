import SwiftUI
import SwiftData

// MARK: - Simulation de course hybride

/// Chronomètre d'une course au format 8 × 1 km + 8 ateliers, segment par
/// segment, avec comparaison à son propre record.
///
/// Pas de GPS : ces courses se préparent en salle, sur tapis, où le GPS ne sert
/// à rien. Un seul geste pendant l'effort — un grand bouton « Suivant » à la
/// fin de chaque kilomètre et de chaque atelier —, parce qu'on n'a ni le temps
/// ni la lucidité pour davantage.
struct HybridRaceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HybridRaceResult.date, order: .reverse) private var results: [HybridRaceResult]

    @AppStorage("profileSex") private var profileSexRaw = UserSex.unspecified.rawValue
    @AppStorage("hybridRaceDivision") private var divisionRaw = ""
    @AppStorage("hybridRaceFormat") private var formatRaw = HybridRace.Format.half.rawValue

    private enum Phase { case setup, racing, finished }

    @State private var phase: Phase = .setup
    @State private var raceStart = Date.now
    @State private var segmentStart = Date.now
    @State private var splits: [Int] = []
    /// Meilleure course du format, figée au départ : une fois la nouvelle
    /// enregistrée, elle deviendrait sa propre référence.
    @State private var reference: [Int]?
    @State private var showAbandon = false

    private var format: HybridRace.Format { HybridRace.Format(rawValue: formatRaw) ?? .half }

    /// Catégorie choisie, sinon déduite du profil (open, la catégorie des premières courses).
    private var division: HybridRace.Division {
        if let chosen = HybridRace.Division(rawValue: divisionRaw) { return chosen }
        return UserSex(stored: profileSexRaw) == .male ? .openMen : .openWomen
    }

    private var segments: [HybridRace.Segment] { HybridRace.segments(for: format) }

    private var best: [Int]? {
        HybridRace.best(of: results.filter { $0.formatRaw == format.rawValue }.map(\.splits),
                        format: format)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .setup:    setup
                case .racing:   racing
                case .finished: finished
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Course hybride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if phase == .racing {
                        Button("Abandonner", role: .destructive) { showAbandon = true }
                    } else {
                        Button("Fermer") { dismiss() }
                    }
                }
            }
            .alert("Abandonner la course ?", isPresented: $showAbandon) {
                Button("Continuer", role: .cancel) {}
                Button("Abandonner", role: .destructive) {
                    keepScreenOn(false)
                    phase = .setup
                }
            } message: {
                Text("Les temps de cette course ne seront pas enregistrés.")
            }
        }
        .interactiveDismissDisabled(phase == .racing)
        .onDisappear { keepScreenOn(false) }
        #if DEBUG
        .onAppear {
            // Captures d'écran automatisées : `-debugHybridStart YES` lance la course.
            if UserDefaults.standard.bool(forKey: "debugHybridStart"), phase == .setup { startRace() }
        }
        #endif
    }

    // MARK: Avant le départ

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("1 km de course, un atelier, et on recommence. Le format qui fait exploser l'entraînement hybride, chronométré segment par segment.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Picker("Format", selection: $formatRaw) {
                    ForEach(HybridRace.Format.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Catégorie").font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("Catégorie", selection: Binding(get: { division.rawValue },
                                                           set: { divisionRaw = $0 })) {
                        ForEach(HybridRace.Division.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let best {
                    Label("Record : \(PaceFormatter.duration(best.reduce(0, +)))",
                          systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                VStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        HStack(spacing: 12) {
                            Image(systemName: symbol(segment))
                                .foregroundStyle(segment.isRun ? .green : .orange)
                                .frame(width: 28)
                            Text(title(segment)).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(detail(segment))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 9)
                        if index < segments.count - 1 { Divider().padding(.leading, 40) }
                    }
                }
                .padding(.horizontal, 14)
                .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Échauffe-toi avant de partir. Touche « Suivant » à la fin de chaque kilomètre et de chaque atelier : le chrono enchaîne tout seul. Effort très intense : adapte les charges à ton niveau.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    startRace()
                } label: {
                    Text("Départ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                if !results.isEmpty { history }
            }
            .padding()
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mes courses").font(.headline).padding(.top, 8)
            ForEach(results.prefix(8)) { result in
                let resultFormat = HybridRace.Format(rawValue: result.formatRaw)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resultFormat?.label ?? result.formatRaw)
                            .font(.subheadline.weight(.medium))
                        Text(result.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(PaceFormatter.duration(result.totalSeconds))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
                .padding(12)
                .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contextMenu {
                    Button(role: .destructive) {
                        context.delete(result)
                        context.saveLogging()
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: Pendant la course

    private var racing: some View {
        let index = min(splits.count, segments.count - 1)
        let segment = segments[index]
        return VStack(spacing: 18) {
            TimelineView(.periodic(from: raceStart, by: 1)) { timeline in
                VStack(spacing: 4) {
                    Text(PaceFormatter.duration(Int(timeline.date.timeIntervalSince(raceStart))))
                        .font(.system(size: 60, weight: .bold, design: .rounded).monospacedDigit())
                    Text("Segment \(index + 1) / \(segments.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(splits.count), total: Double(segments.count))
                .tint(.orange)

            VStack(spacing: 8) {
                Image(systemName: symbol(segment))
                    .font(.system(size: 34))
                    .foregroundStyle(segment.isRun ? .green : .orange)
                Text(title(segment)).font(.title2.bold())
                Text(detail(segment)).font(.headline).foregroundStyle(.secondary)
                TimelineView(.periodic(from: segmentStart, by: 1)) { timeline in
                    Text(PaceFormatter.duration(Int(timeline.date.timeIntervalSince(segmentStart))))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                if let reference, index < reference.count {
                    Text("Ton record sur ce segment : \(PaceFormatter.duration(reference[index]))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if let last = splits.last {
                HStack(spacing: 6) {
                    Text("Segment précédent : \(PaceFormatter.duration(last))")
                    if let delta = HybridRace.deltas(splits: splits, reference: reference).last ?? nil {
                        Text(deltaText(delta)).foregroundStyle(delta <= 0 ? .green : .orange)
                    }
                }
                .font(.footnote.monospacedDigit())
            }
            if index + 1 < segments.count {
                Text("Ensuite : \(title(segments[index + 1]))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                nextSegment()
            } label: {
                Text(index + 1 == segments.count ? "Terminer" : "Suivant")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
            }
            .buttonStyle(.borderedProminent)
            .tint(segment.isRun ? .green : .orange)
        }
        .padding()
    }

    // MARK: Arrivée

    private var finished: some View {
        let total = splits.reduce(0, +)
        let totals = HybridRace.totals(splits: splits, format: format)
        let referenceTotal = reference?.reduce(0, +)
        let isRecord = referenceTotal.map { total < $0 } ?? false
        let deltas = HybridRace.deltas(splits: splits, reference: reference)

        return ScrollView {
            VStack(spacing: 16) {
                Image(systemName: isRecord ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 48))
                    .foregroundStyle(isRecord ? .yellow : .orange)
                Text(isRecord ? "Nouveau record !" : "Course terminée")
                    .font(.title.bold())
                Text(PaceFormatter.duration(total))
                    .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                if let referenceTotal {
                    Text("Record précédent : \(PaceFormatter.duration(referenceTotal)) (\(deltaText(total - referenceTotal)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    tile(PaceFormatter.duration(totals.running), String(localized: "en course"), .green)
                    tile(PaceFormatter.duration(totals.stations), String(localized: "sur les ateliers"), .orange)
                }

                Text(insight(deltas: deltas))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.orange.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        HStack {
                            Text(title(segment)).font(.subheadline)
                            Spacer()
                            if index < splits.count {
                                Text(PaceFormatter.duration(splits[index]))
                                    .font(.subheadline.monospacedDigit().weight(.medium))
                            }
                            if index < deltas.count, let delta = deltas[index] {
                                Text(deltaText(delta))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(delta <= 0 ? .green : .orange)
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 8)
                        if index < segments.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    dismiss()
                } label: {
                    Text("Terminer").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
        }
        .overlay {
            if isRecord { ConfettiView() }
        }
    }

    /// Une phrase qui dit où chercher le temps, plutôt qu'un tableau à déchiffrer.
    private func insight(deltas: [Int?]) -> String {
        guard reference != nil else {
            return String(localized: "Premier chrono enregistré : ta prochaine course se comparera à celle-ci, segment par segment.")
        }
        if let loss = HybridRace.biggestLoss(splits: splits, reference: reference) {
            return String(localized: "C'est sur « \(title(segments[loss.index])) » que tu as perdu le plus de temps par rapport à ton record (\(deltaText(loss.seconds))).")
        }
        return String(localized: "Aussi rapide ou plus rapide que ton record sur chaque segment.")
    }

    private func tile(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Libellés

    private func title(_ segment: HybridRace.Segment) -> String {
        switch segment {
        case .run(let number): String(localized: "Course \(number)")
        case .station(let station): station.name
        }
    }

    private func detail(_ segment: HybridRace.Segment) -> String {
        switch segment {
        case .run:
            return String(localized: "1 km")
        case .station(let station):
            var parts: [String] = []
            if let meters = station.meters { parts.append("\(meters.formatted()) m") }
            if let reps = station.reps { parts.append(String(localized: "\(reps) reps")) }
            if let kg = station.load(for: division) {
                parts.append(station.isPair ? "2 × \(kg.localizedClean) kg" : "\(kg.localizedClean) kg")
            }
            return parts.joined(separator: " · ")
        }
    }

    private func symbol(_ segment: HybridRace.Segment) -> String {
        switch segment {
        case .run: "figure.run"
        case .station(let station): station.symbol
        }
    }

    /// « −0:12 » plus rapide, « +0:25 » plus lent.
    private func deltaText(_ seconds: Int) -> String {
        if seconds == 0 { return "=" }
        return (seconds < 0 ? "−" : "+") + PaceFormatter.duration(abs(seconds))
    }

    // MARK: Chronométrage

    private func startRace() {
        reference = best
        splits = []
        raceStart = .now
        segmentStart = raceStart
        phase = .racing
        keepScreenOn(true)
        Feedback.cue(2)
    }

    private func nextSegment() {
        let now = Date.now
        splits.append(max(1, Int(now.timeIntervalSince(segmentStart).rounded())))
        segmentStart = now
        if splits.count >= segments.count {
            finishRace()
        } else {
            // Deux bips avant une course, un avant un atelier : on sait où on
            // en est sans regarder l'écran.
            Feedback.cue(segments[splits.count].isRun ? 2 : 1)
        }
    }

    private func finishRace() {
        keepScreenOn(false)
        let result = HybridRaceResult(date: raceStart, formatRaw: format.rawValue,
                                      divisionRaw: division.rawValue, splits: splits)
        context.insert(result)
        context.saveLogging()

        let totals = HybridRace.totals(splits: splits, format: format)
        let weight = UserDefaults.standard.double(forKey: "profileWeightKg")
        let kg = weight > 0 ? weight : 70
        let kcal = CalorieEstimator.runKcal(distanceKm: Double(format.stationCount), weightKg: kg)
            + CalorieEstimator.workoutKcal(durationSeconds: totals.stations, weightKg: kg)
        let start = raceStart, duration = result.totalSeconds
        let meters = Double(format.stationCount) * 1000
        Task {
            await HealthKitManager.shared.saveHybridRace(start: start, durationSeconds: duration,
                                                         kcal: kcal, distanceMeters: meters)
        }

        Feedback.workoutFinished()
        phase = .finished
    }

    /// L'écran reste allumé pendant la course : on le regarde entre deux
    /// ateliers, les mains prises, sans pouvoir le déverrouiller.
    private func keepScreenOn(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
    }
}
