import Foundation

// MARK: - Plans d'entraînement

/// Plans 10 km / semi / marathon, sur une progression classique en trois phases
/// suivies d'une semaine d'affûtage.
///
/// Les plans ont une **structure fixe** mais des **allures personnalisées** :
/// chaque séance affiche la fourchette calculée depuis la VMA mesurée. C'est là
/// qu'est la valeur de coaching, et ce qui justifie le test de VMA.
///
/// Ils ne sont volontairement **pas adaptatifs** : un plan qui se réajuste selon
/// les séances manquées demande de vraies règles d'entraînement (quand rattraper,
/// quand sauter, quand reculer l'objectif) qu'on ne peut pas improviser sans
/// risquer de faire blesser quelqu'un.
enum TrainingPlans {

    /// Trois séances par semaine : le compromis qui permet de progresser sans
    /// exiger une disponibilité que la plupart des gens n'ont pas.
    static let sessionsPerWeek = 3

    // MARK: Objectifs

    enum Goal: String, CaseIterable, Identifiable {
        case tenK, half, marathon
        var id: String { rawValue }

        var label: String {
            switch self {
            case .tenK:     String(localized: "run.goal.tenK")
            case .half:     String(localized: "run.goal.half")
            case .marathon: String(localized: "run.goal.marathon")
            }
        }

        var weekCount: Int {
            switch self {
            case .tenK: 8
            case .half: 10
            case .marathon: 12
            }
        }

        /// Sortie longue : durée de départ et durée au pic, en minutes.
        var longRun: (start: Int, peak: Int) {
            switch self {
            case .tenK:     (55, 80)
            case .half:     (70, 105)
            case .marathon: (80, 150)
            }
        }

        /// Zone travaillée en phase spécifique : l'allure du jour J.
        var racePaceZone: RunningScience.Zone {
            switch self {
            case .tenK:     .tenK
            case .half:     .halfMarathon
            case .marathon: .marathon
            }
        }
    }

    // MARK: Phases

    enum Phase: String {
        case base, development, specific, taper

        var label: String {
            switch self {
            case .base:        String(localized: "run.phase.base")
            case .development: String(localized: "run.phase.development")
            case .specific:    String(localized: "run.phase.specific")
            case .taper:       String(localized: "run.phase.taper")
            }
        }

        var advice: String {
            switch self {
            case .base:        String(localized: "run.phase.base.advice")
            case .development: String(localized: "run.phase.development.advice")
            case .specific:    String(localized: "run.phase.specific.advice")
            case .taper:       String(localized: "run.phase.taper.advice")
            }
        }
    }

    // MARK: Séances

    struct Session: Identifiable {
        enum Kind: String {
            case easy, quality, longRun

            var label: String {
                switch self {
                case .easy:    String(localized: "run.session.easy")
                case .quality: String(localized: "run.session.quality")
                case .longRun: String(localized: "run.session.longRun")
                }
            }
        }

        /// Structure d'un fractionné. nil pour une séance continue.
        struct Intervals: Hashable {
            let reps: Int
            let effortSeconds: Int
            let recoverySeconds: Int
        }

        let id = UUID()
        let kind: Kind
        /// Durée totale indicative, échauffement et retour au calme compris.
        let minutes: Int
        let zone: RunningScience.Zone
        let intervals: Intervals?
    }

    struct Week: Identifiable {
        let id = UUID()
        let number: Int
        let phase: Phase
        let sessions: [Session]
    }

    // MARK: Construction

    /// Phase d'une semaine donnée. La dernière semaine est toujours l'affûtage,
    /// le reste est découpé en trois tiers.
    static func phase(week: Int, of total: Int) -> Phase {
        if week >= total { return .taper }
        let third = max(1, (total - 1) / 3)
        if week <= third { return .base }
        if week <= third * 2 { return .development }
        return .specific
    }

    /// Le plan complet pour un objectif.
    static func weeks(for goal: Goal) -> [Week] {
        let total = goal.weekCount
        return (1...total).map { number in
            let ph = phase(week: number, of: total)
            return Week(number: number, phase: ph,
                        sessions: [
                            easySession(phase: ph),
                            qualitySession(phase: ph, week: number, goal: goal),
                            longRunSession(week: number, goal: goal, phase: ph),
                        ])
        }
    }

    private static func easySession(phase: Phase) -> Session {
        Session(kind: .easy,
                minutes: phase == .taper ? 30 : 45,
                zone: .easy,
                intervals: nil)
    }

    private static func qualitySession(phase: Phase, week: Int, goal: Goal) -> Session {
        switch phase {
        case .base:
            // VMA courte : 30/30, on monte progressivement le nombre de fractions.
            let reps = min(8 + (week - 1) * 2, 16)
            return Session(kind: .quality, minutes: 40, zone: .vmaShort,
                           intervals: .init(reps: reps, effortSeconds: 30, recoverySeconds: 30))
        case .development:
            // VMA longue : fractions de 3 min, récupération à mi-durée.
            //
            // On compte la position DANS la phase, pas la semaine absolue : un
            // `week % 3` faisait redescendre le nombre de fractions (5 → 6 → 4),
            // ce qui se lit comme un bug plutôt que comme une progression.
            let third = max(1, (goal.weekCount - 1) / 3)
            let indexInPhase = max(0, week - third - 1)
            let reps = min(4 + indexInPhase, 6)
            return Session(kind: .quality, minutes: 50, zone: .vmaLong,
                           intervals: .init(reps: reps, effortSeconds: 180, recoverySeconds: 90))
        case .specific:
            // Allure du jour J, en blocs longs.
            return Session(kind: .quality, minutes: 55, zone: goal.racePaceZone,
                           intervals: .init(reps: 3, effortSeconds: 600, recoverySeconds: 180))
        case .taper:
            // On garde du rythme sans fatiguer.
            return Session(kind: .quality, minutes: 30, zone: goal.racePaceZone,
                           intervals: .init(reps: 4, effortSeconds: 180, recoverySeconds: 120))
        }
    }

    private static func longRunSession(week: Int, goal: Goal, phase: Phase) -> Session {
        let total = goal.weekCount
        let (start, peak) = goal.longRun

        // Affûtage : on coupe franchement la sortie longue.
        guard phase != .taper else {
            return Session(kind: .longRun, minutes: start / 2, zone: .easy, intervals: nil)
        }

        // Progression linéaire jusqu'au pic, atteint la semaine avant l'affûtage,
        // arrondie à 5 min pour rester lisible.
        let peakWeek = max(2, total - 1)
        let ratio = min(1, Double(week - 1) / Double(peakWeek - 1))
        let raw = Double(start) + (Double(peak) - Double(start)) * ratio
        let minutes = Int((raw / 5).rounded()) * 5

        // À partir de la phase spécifique, la sortie longue se court en partie à
        // l'allure cible.
        let zone: RunningScience.Zone = phase == .specific ? goal.racePaceZone : .easy
        return Session(kind: .longRun, minutes: minutes, zone: zone, intervals: nil)
    }
}
