import Foundation
import ActivityKit

/// Pilote les Live Activities depuis l'app (mise à jour locale, sans serveur push).
/// Compatible compte gratuit tant que les updates viennent de l'app pendant qu'elle tourne.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var restActivity: Activity<RestActivityAttributes>?
    private var runActivity: Activity<RunActivityAttributes>?

    private var enabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: Timer de repos

    func startRest(exerciseName: String, workoutName: String, seconds: Int) {
        guard enabled else { return }
        endRest()
        let state = RestActivityAttributes.ContentState(
            exerciseName: exerciseName,
            endDate: Date.now.addingTimeInterval(TimeInterval(seconds)),
            totalSeconds: seconds
        )
        do {
            restActivity = try Activity.request(
                attributes: RestActivityAttributes(workoutName: workoutName),
                content: .init(state: state, staleDate: state.endDate.addingTimeInterval(5))
            )
        } catch {
            print("Live Activity repos KO : \(error)")
        }
    }

    func updateRest(exerciseName: String, endDate: Date, totalSeconds: Int) {
        guard let restActivity else { return }
        let state = RestActivityAttributes.ContentState(
            exerciseName: exerciseName, endDate: endDate, totalSeconds: totalSeconds
        )
        Task { await restActivity.update(.init(state: state, staleDate: endDate.addingTimeInterval(5))) }
    }

    func endRest() {
        guard let restActivity else { return }
        Task { await restActivity.end(nil, dismissalPolicy: .immediate) }
        self.restActivity = nil
    }

    // MARK: Course

    func startRun() {
        guard enabled else { return }
        endRun()
        let state = RunActivityAttributes.ContentState(distanceMeters: 0, elapsedSeconds: 0, paceSecPerKm: 0)
        do {
            runActivity = try Activity.request(
                attributes: RunActivityAttributes(startedAt: .now),
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("Live Activity course KO : \(error)")
        }
    }

    func updateRun(distanceMeters: Double, elapsedSeconds: Int, paceSecPerKm: Double) {
        guard let runActivity else { return }
        let state = RunActivityAttributes.ContentState(
            distanceMeters: distanceMeters, elapsedSeconds: elapsedSeconds, paceSecPerKm: paceSecPerKm
        )
        Task { await runActivity.update(.init(state: state, staleDate: nil)) }
    }

    func endRun() {
        guard let runActivity else { return }
        Task { await runActivity.end(nil, dismissalPolicy: .immediate) }
        self.runActivity = nil
    }
}
