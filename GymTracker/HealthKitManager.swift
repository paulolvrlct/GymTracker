import Foundation
import HealthKit
import SwiftData

// MARK: - Intégration Apple Santé (écriture uniquement)
// Séances et courses enregistrées comme entraînements, journal alimentaire
// vers les données nutrition. La lecture (ex. courses faites à la montre)
// viendra avec l'app watchOS.

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()
    private init() {}

    private var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(),
         HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.distanceWalkingRunning),
         HKQuantityType(.dietaryEnergyConsumed),
         HKQuantityType(.dietaryProtein),
         HKQuantityType(.dietaryCarbohydrates),
         HKQuantityType(.dietaryFatTotal)]
    }

    /// Ne présente la demande qu'au premier appel ; no-op ensuite.
    private func ensureAuthorization() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: writeTypes, read: [])
    }

    // MARK: Connexion depuis l'interface

    /// Apple Santé est-il disponible sur cet appareil ?
    var isHealthAvailable: Bool { isAvailable }

    /// Vrai si l'utilisateur a autorisé LiftRun à écrire ses entraînements.
    var isSharingAuthorized: Bool {
        guard isAvailable else { return false }
        return store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    /// Demande d'autorisation déclenchée explicitement depuis l'écran Profil,
    /// pour que l'intégration Apple Santé soit visible et maîtrisée par l'utilisateur.
    func connect() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    /// Types lus : le poids (profil), les entraînements de la montre et des
    /// autres apps, le sommeil et la variabilité cardiaque (forme du jour).
    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.bodyMass),
         HKObjectType.workoutType(),
         HKQuantityType(.distanceWalkingRunning),
         HKQuantityType(.distanceCycling),
         HKQuantityType(.distanceSwimming),
         HKCategoryType(.sleepAnalysis),
         HKQuantityType(.heartRateVariabilitySDNN)]
    }

    private func samples(of type: HKSampleType, from start: Date, to end: Date) async -> [HKSample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                continuation.resume(returning: results ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: Import des entraînements (montre, autres apps)

    /// Importe les entraînements récents enregistrés par d'autres sources que
    /// LiftRun : la course faite avec la montre compte enfin dans la forme du
    /// jour. Renvoie le nombre d'entraînements ajoutés.
    ///
    /// Trois protections contre le double comptage : les entraînements écrits
    /// par LiftRun lui-même sont exclus, chaque entraînement Santé n'est
    /// importé qu'une fois (UUID), et un entraînement de montre qui chevauche
    /// une séance ou une course suivie dans LiftRun est ignoré.
    @discardableResult
    func importWorkouts(context: ModelContext, days: Int = 30) async -> Int {
        guard isAvailable else { return 0 }
        try? await store.requestAuthorization(toShare: [], read: readTypes)

        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let workouts = await samples(of: .workoutType(), from: start, to: .now)
            .compactMap { $0 as? HKWorkout }
            .sorted { $0.startDate < $1.startDate }

        let ownBundle = Bundle.main.bundleIdentifier ?? "fr.devshield.gymtracker"
        let runs = (try? context.fetch(FetchDescriptor<RunSession>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let others = (try? context.fetch(FetchDescriptor<ImportedActivity>())) ?? []
        let known = Set(runs.map(\.healthUUID) + others.map(\.healthUUID))

        // Intervalles des activités suivies par LiftRun (une séance sans durée
        // compte pour 30 min), à 10 min près.
        let ownIntervals: [(start: Date, end: Date)] =
            sessions.map { ($0.date, $0.date.addingTimeInterval(Double(max($0.durationSeconds, 1800)))) }
            + runs.filter { $0.healthUUID.isEmpty }
                .map { ($0.date.addingTimeInterval(-Double($0.durationSeconds)), $0.date) }
        func overlapsOwnActivity(_ workout: HKWorkout) -> Bool {
            ownIntervals.contains {
                workout.startDate < $0.end.addingTimeInterval(600)
                    && workout.endDate > $0.start.addingTimeInterval(-600)
            }
        }

        var added = 0
        for workout in workouts {
            let id = workout.uuid.uuidString
            let sourceBundle = workout.sourceRevision.source.bundleIdentifier
            guard !known.contains(id), !sourceBundle.hasPrefix(ownBundle),
                  !overlapsOwnActivity(workout) else { continue }
            let source = workout.sourceRevision.source.name

            if workout.workoutActivityType == .running {
                let meters = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                    .sumQuantity()?.doubleValue(for: .meter()) ?? 0
                // Une course sans distance (tapis sans capteur) ne donnerait
                // aucune allure : elle compte alors comme une activité cardio.
                if meters >= 200 {
                    let run = RunSession(date: workout.endDate, distanceMeters: meters,
                                         durationSeconds: Int(workout.duration))
                    run.healthUUID = id
                    run.sourceName = source
                    context.insert(run)
                    added += 1
                    continue
                }
            }

            let kind = workout.workoutActivityType == .running
                ? "other" : Self.importedKind(for: workout.workoutActivityType)
            guard let kind else { continue }
            let distance = [HKQuantityType(.distanceCycling), HKQuantityType(.distanceSwimming),
                            HKQuantityType(.distanceWalkingRunning)]
                .compactMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) }
                .first ?? 0
            context.insert(ImportedActivity(date: workout.startDate, kindRaw: kind,
                                            durationSeconds: Int(workout.duration),
                                            distanceMeters: distance, sourceName: source,
                                            healthUUID: id))
            added += 1
        }
        if added > 0 { context.saveLogging() }
        return added
    }

    /// Famille d'activité du moteur (`ImportedKind.rawValue`) pour un type
    /// d'entraînement Santé. nil : activité trop légère pour peser (yoga,
    /// étirements, golf…), ignorée.
    static func importedKind(for type: HKWorkoutActivityType) -> String? {
        switch type {
        case .cycling, .handCycling: "cycling"
        case .swimming, .waterFitness: "swimming"
        case .rowing, .paddleSports: "rowing"
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio, .jumpRope,
             .kickboxing, .boxing, .martialArts: "hiit"
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: "strength"
        case .walking: "walking"
        case .hiking: "hiking"
        case .elliptical, .stairClimbing, .stairs, .stepTraining, .soccer, .basketball,
             .tennis, .rugby, .handball, .volleyball, .cardioDance, .socialDance, .climbing: "other"
        default: nil
        }
    }

    // MARK: Sommeil et variabilité cardiaque

    /// Nuit dernière et variabilité cardiaque du jour. nil si Santé n'a ni
    /// l'un ni l'autre (pas de montre, pas de suivi du sommeil).
    func recoverySignals(now: Date = .now) async -> RecoverySignals? {
        guard isAvailable else { return nil }
        let sleep = await lastNightSleepHours(now: now)
        let hrv = await hrvRatio(now: now)
        guard sleep != nil || hrv != nil else { return nil }
        return RecoverySignals(sleepHours: sleep, hrvRatio: hrv)
    }

    /// Sommeil de la nuit dernière (18 h la veille → 14 h), en heures.
    ///
    /// Montre et iPhone enregistrent souvent la même nuit : les intervalles
    /// sont fusionnés pour ne jamais compter deux fois le même sommeil.
    private func lastNightSleepHours(now: Date) async -> Double? {
        let today = Calendar.current.startOfDay(for: now)
        let windowStart = today.addingTimeInterval(-6 * 3600)
        let windowEnd = min(now, today.addingTimeInterval(14 * 3600))
        guard windowEnd > windowStart else { return nil }

        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        let intervals = await samples(of: HKCategoryType(.sleepAnalysis), from: windowStart, to: windowEnd)
            .compactMap { $0 as? HKCategorySample }
            .filter { asleep.contains($0.value) }
            .map { (start: max($0.startDate, windowStart), end: min($0.endDate, windowEnd)) }
            .filter { $0.start < $0.end }
            .sorted { $0.start < $1.start }

        var total: TimeInterval = 0
        var current: (start: Date, end: Date)?
        for interval in intervals {
            if let open = current, interval.start <= open.end {
                current = (open.start, max(open.end, interval.end))
            } else {
                if let open = current { total += open.end.timeIntervalSince(open.start) }
                current = interval
            }
        }
        if let open = current { total += open.end.timeIntervalSince(open.start) }

        // Moins d'une heure : la nuit n'a pas été suivie, mieux vaut ne rien dire.
        return total >= 3600 ? total / 3600 : nil
    }

    /// Variabilité cardiaque des dernières 24 h rapportée à la moyenne des
    /// 30 jours précédents. Au moins 7 mesures de référence sont exigées :
    /// une moyenne sur trois valeurs ne vaut rien.
    private func hrvRatio(now: Date) async -> Double? {
        let unit = HKUnit.secondUnit(with: .milli)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let dayAgo = now.addingTimeInterval(-86_400)
        let values = await samples(of: HKQuantityType(.heartRateVariabilitySDNN), from: start, to: now)
            .compactMap { $0 as? HKQuantitySample }
            .map { (date: $0.endDate, ms: $0.quantity.doubleValue(for: unit)) }
        let recent = values.filter { $0.date >= dayAgo }.map(\.ms)
        let baseline = values.filter { $0.date < dayAgo }.map(\.ms)
        guard !recent.isEmpty, baseline.count >= 7 else { return nil }
        let baselineMean = baseline.reduce(0, +) / Double(baseline.count)
        guard baselineMean > 0 else { return nil }
        return (recent.reduce(0, +) / Double(recent.count)) / baselineMean
    }

    // MARK: Entraînements

    /// Séance de musculation terminée
    func saveStrengthWorkout(start: Date, durationSeconds: Int, kcal: Int) async {
        await saveWorkout(activity: .traditionalStrengthTraining,
                          start: start, durationSeconds: durationSeconds,
                          kcal: kcal, distanceMeters: nil)
    }

    /// Course terminée
    func saveRun(start: Date, durationSeconds: Int, kcal: Int, distanceMeters: Double) async {
        await saveWorkout(activity: .running,
                          start: start, durationSeconds: durationSeconds,
                          kcal: kcal, distanceMeters: distanceMeters)
    }

    /// Simulation de course hybride : entraînement croisé, avec la distance courue.
    func saveHybridRace(start: Date, durationSeconds: Int, kcal: Int, distanceMeters: Double) async {
        await saveWorkout(activity: .crossTraining,
                          start: start, durationSeconds: durationSeconds,
                          kcal: kcal, distanceMeters: distanceMeters)
    }

    private func saveWorkout(activity: HKWorkoutActivityType, start: Date,
                             durationSeconds: Int, kcal: Int, distanceMeters: Double?) async {
        guard isAvailable, durationSeconds > 0 else { return }
        await ensureAuthorization()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        let end = start.addingTimeInterval(TimeInterval(durationSeconds))

        do {
            try await builder.beginCollection(at: start)
            var samples: [HKSample] = []
            if kcal > 0 {
                samples.append(HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(kcal)),
                    start: start, end: end))
            }
            if let distanceMeters, distanceMeters > 0 {
                samples.append(HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
                    start: start, end: end))
            }
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // Santé indisponible ou refusée : l'app reste pleinement fonctionnelle
        }
    }

    // MARK: Lecture du poids (opt-in)

    /// Lit le poids le plus récent enregistré dans Apple Santé (kg), si disponible
    /// et autorisé. Sert à pré-remplir le profil sans ressaisie.
    func latestBodyMassKg() async -> Double? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(.bodyMass)
        try? await store.requestAuthorization(toShare: [], read: [type])
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                      sortDescriptors: [sort]) { _, results, _ in
                let kg = (results?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    // MARK: Rattrapage de l'historique

    /// Exporte une seule fois l'historique existant (séances + courses) vers
    /// Santé — couvre les entraînements réalisés avant l'intégration HealthKit.
    func backfillIfNeeded(context: ModelContext) async {
        guard isAvailable else { return }
        let flag = "healthBackfillDone"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        await ensureAuthorization()

        let weight = UserDefaults.standard.double(forKey: "profileWeightKg")
        let kg = weight > 0 ? weight : 70

        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        for session in sessions where session.durationSeconds > 0 {
            await saveStrengthWorkout(
                start: session.date,
                durationSeconds: session.durationSeconds,
                kcal: CalorieEstimator.workoutKcal(durationSeconds: session.durationSeconds,
                                                   weightKg: kg,
                                                   volumeKg: session.totalVolume,
                                                   bodyweightReps: session.bodyweightReps))
        }
        let runs = (try? context.fetch(FetchDescriptor<RunSession>())) ?? []
        // Une course importée de Santé y est déjà : ne pas la réécrire.
        for run in runs where run.durationSeconds > 0 && run.healthUUID.isEmpty {
            await saveRun(
                start: run.date.addingTimeInterval(-TimeInterval(run.durationSeconds)),
                durationSeconds: run.durationSeconds,
                kcal: CalorieEstimator.runKcal(distanceKm: run.distanceKm, weightKg: kg),
                distanceMeters: run.distanceMeters)
        }
        UserDefaults.standard.set(true, forKey: flag)
    }

    // MARK: Nutrition

    private var dietaryTypes: [(HKQuantityType, HKUnit)] {
        [(HKQuantityType(.dietaryEnergyConsumed), .kilocalorie()),
         (HKQuantityType(.dietaryProtein), .gram()),
         (HKQuantityType(.dietaryCarbohydrates), .gram()),
         (HKQuantityType(.dietaryFatTotal), .gram())]
    }

    /// Écrit un aliment consommé ; renvoie les UUID des échantillons créés
    /// (à conserver pour pouvoir les supprimer avec l'entrée du journal).
    func saveFood(kcal: Double, protein: Double, carbs: Double, fat: Double,
                  date: Date, name: String) async -> [String] {
        guard isAvailable else { return [] }
        await ensureAuthorization()

        let metadata = [HKMetadataKeyFoodType: name]
        let values = [kcal, protein, carbs, fat]
        var samples: [HKQuantitySample] = []
        for (index, (type, unit)) in dietaryTypes.enumerated() where values[index] > 0 {
            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: values[index]),
                start: date, end: date, metadata: metadata))
        }
        guard !samples.isEmpty else { return [] }
        do {
            try await store.save(samples)
            return samples.map { $0.uuid.uuidString }
        } catch {
            return []
        }
    }

    /// Supprime les échantillons Santé liés à une entrée du journal
    func deleteFoodSamples(ids: [String]) async {
        guard isAvailable else { return }
        let uuids = Set(ids.compactMap(UUID.init))
        guard !uuids.isEmpty else { return }

        for (type, _) in dietaryTypes {
            let predicate = HKQuery.predicateForObjects(with: uuids)
            let samples: [HKSample] = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                          limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                    continuation.resume(returning: results ?? [])
                }
                store.execute(query)
            }
            if !samples.isEmpty {
                try? await store.delete(samples)
            }
        }
    }
}
