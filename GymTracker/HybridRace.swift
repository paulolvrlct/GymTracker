import Foundation

// MARK: - Course hybride (format « fitness race »)

/// Simulation d'une course au format 8 × 1 km de course à pied, chacun suivi
/// d'un atelier fonctionnel.
///
/// C'est le format qui a fait exploser l'entraînement hybride : 650 000
/// participants sur la saison 2024-2025, 1,5 million sur la suivante. Et c'est
/// exactement le terrain de LiftRun — ni une app de muscu ni une app de course
/// ne sait chronométrer un enchaînement des deux.
///
/// Aucune marque n'est employée : les ateliers portent leur nom générique, et
/// les charges sont celles, publiques, des catégories de ce type de course.
enum HybridRace {

    // MARK: Catégories

    enum Division: String, CaseIterable, Identifiable {
        case openWomen, openMen, proWomen, proMen

        var id: String { rawValue }

        var label: String {
            switch self {
            case .openWomen: String(localized: "hybrid.division.openWomen")
            case .openMen:   String(localized: "hybrid.division.openMen")
            case .proWomen:  String(localized: "hybrid.division.proWomen")
            case .proMen:    String(localized: "hybrid.division.proMen")
            }
        }

        /// Choisit la charge adaptée à la catégorie, dans l'ordre
        /// open femmes, open hommes, pro femmes, pro hommes.
        func pick(_ openWomen: Double, _ openMen: Double,
                  _ proWomen: Double, _ proMen: Double) -> Double {
            switch self {
            case .openWomen: openWomen
            case .openMen:   openMen
            case .proWomen:  proWomen
            case .proMen:    proMen
            }
        }
    }

    // MARK: Formats

    enum Format: String, CaseIterable, Identifiable {
        /// 8 × 1 km + 8 ateliers : la course réelle.
        case full
        /// 4 × 1 km + les 4 premiers ateliers : la séance d'entraînement type.
        case half

        var id: String { rawValue }

        var stationCount: Int { self == .full ? 8 : 4 }

        var label: String {
            switch self {
            case .full: String(localized: "hybrid.format.full")
            case .half: String(localized: "hybrid.format.half")
            }
        }
    }

    // MARK: Ateliers

    enum Station: String, CaseIterable {
        case skiErg, sledPush, sledPull, burpeeBroadJump,
             rowing, farmersCarry, sandbagLunges, wallBalls

        var name: String {
            switch self {
            case .skiErg:          String(localized: "hybrid.station.skiErg")
            case .sledPush:        String(localized: "hybrid.station.sledPush")
            case .sledPull:        String(localized: "hybrid.station.sledPull")
            case .burpeeBroadJump: String(localized: "hybrid.station.burpeeBroadJump")
            case .rowing:          String(localized: "hybrid.station.rowing")
            case .farmersCarry:    String(localized: "hybrid.station.farmersCarry")
            case .sandbagLunges:   String(localized: "hybrid.station.sandbagLunges")
            case .wallBalls:       String(localized: "hybrid.station.wallBalls")
            }
        }

        var symbol: String {
            switch self {
            case .skiErg:          "figure.skiing.crosscountry"
            case .sledPush:        "arrow.right.to.line"
            case .sledPull:        "arrow.left.to.line"
            case .burpeeBroadJump: "figure.jumprope"
            case .rowing:          "figure.rower"
            case .farmersCarry:    "figure.walk"
            case .sandbagLunges:   "figure.strengthtraining.functional"
            case .wallBalls:       "basketball.fill"
            }
        }

        /// Distance en mètres, ou nil pour un atelier compté en répétitions.
        var meters: Int? {
            switch self {
            case .skiErg, .rowing: 1000
            case .sledPush, .sledPull: 50
            case .burpeeBroadJump: 80
            case .farmersCarry: 200
            case .sandbagLunges: 100
            case .wallBalls: nil
            }
        }

        var reps: Int? { self == .wallBalls ? 100 : nil }

        /// Charge en kg selon la catégorie (traîneau compris), nil si aucune.
        func load(for division: Division) -> Double? {
            switch self {
            case .sledPush:      division.pick(102, 152, 152, 202)
            case .sledPull:      division.pick(78, 103, 103, 153)
            case .farmersCarry:  division.pick(16, 24, 24, 32)
            case .sandbagLunges: division.pick(10, 20, 20, 30)
            case .wallBalls:     division.pick(4, 6, 6, 9)
            default:             nil
            }
        }

        /// Les deux poignées pour le porté de charges.
        var isPair: Bool { self == .farmersCarry }
    }

    // MARK: Déroulé

    enum Segment: Equatable {
        /// Kilomètre de course, numéroté à partir de 1.
        case run(number: Int)
        case station(Station)

        var isRun: Bool {
            if case .run = self { return true }
            return false
        }
    }

    /// Course, atelier, course, atelier… dans l'ordre officiel.
    static func segments(for format: Format) -> [Segment] {
        Station.allCases.prefix(format.stationCount).enumerated().flatMap { index, station in
            [Segment.run(number: index + 1), .station(station)]
        }
    }

    // MARK: Analyse

    /// Écart par segment avec une course de référence (secondes ; négatif =
    /// plus rapide). nil pour un segment sans référence.
    static func deltas(splits: [Int], reference: [Int]?) -> [Int?] {
        splits.indices.map { index in
            guard let reference, index < reference.count else { return nil }
            return splits[index] - reference[index]
        }
    }

    /// Temps cumulés en course et en ateliers : la question que se pose tout
    /// athlète hybride — est-ce que je perds mon temps en courant, ou sur les
    /// ateliers ?
    static func totals(splits: [Int], format: Format) -> (running: Int, stations: Int) {
        let segments = segments(for: format)
        var running = 0, stations = 0
        for (index, split) in splits.enumerated() where index < segments.count {
            if segments[index].isRun { running += split } else { stations += split }
        }
        return (running, stations)
    }

    /// Segment où l'on a perdu le plus de temps par rapport à la référence.
    static func biggestLoss(splits: [Int], reference: [Int]?) -> (index: Int, seconds: Int)? {
        let losses = deltas(splits: splits, reference: reference).enumerated()
            .compactMap { index, delta in delta.map { (index, $0) } }
            .filter { $0.1 > 0 }
        return losses.max { $0.1 < $1.1 }.map { (index: $0.0, seconds: $0.1) }
    }

    /// Meilleure course parmi des résultats complets du même format.
    static func best(of results: [[Int]], format: Format) -> [Int]? {
        let expected = segments(for: format).count
        return results.filter { $0.count == expected }
            .min { $0.reduce(0, +) < $1.reduce(0, +) }
    }
}
