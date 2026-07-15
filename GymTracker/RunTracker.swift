import Foundation
import CoreLocation
import Combine

/// Suit la position GPS pendant une course, calcule distance / allure / durée
/// et met à jour la Live Activity (Dynamic Island + écran verrouillé).
@MainActor
final class RunTracker: NSObject, ObservableObject {

    // État publié pour l'UI
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: Int = 0
    @Published var currentPaceSecPerKm: Double = 0
    @Published var route: [CLLocationCoordinate2D] = []
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startDate: Date?
    private var timer: Timer?

    // Fenêtre glissante pour lisser l'allure instantanée
    private var recentSegments: [(distance: Double, time: TimeInterval)] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
    }

    // MARK: Contrôle

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard !isRunning else { return }
        reset()
        isRunning = true
        isPaused = false
        startDate = .now

        manager.allowsBackgroundLocationUpdates = true   // suivi écran verrouillé
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        LiveActivityManager.shared.startRun()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            manager.stopUpdatingLocation()
            lastLocation = nil
        } else {
            manager.startUpdatingLocation()
        }
    }

    /// Termine et renvoie les données à persister (nil si trop court)
    func finish() -> (distance: Double, duration: Int, route: String)? {
        guard isRunning else { return nil }
        isRunning = false
        isPaused = false
        timer?.invalidate(); timer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        LiveActivityManager.shared.endRun()

        guard distanceMeters > 20 else { return nil }
        let encoded = route.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
        return (distanceMeters, elapsedSeconds, encoded)
    }

    func reset() {
        distanceMeters = 0
        elapsedSeconds = 0
        currentPaceSecPerKm = 0
        route = []
        recentSegments = []
        lastLocation = nil
        startDate = nil
    }

    // MARK: Timer

    private func tick() {
        guard isRunning, !isPaused, let startDate else { return }
        elapsedSeconds = Int(Date.now.timeIntervalSince(startDate))
        LiveActivityManager.shared.updateRun(
            distanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            paceSecPerKm: currentPaceSecPerKm
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension RunTracker: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                // Filtre les points imprécis
                guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 25 else { continue }
                guard isRunning, !isPaused else { lastLocation = location; continue }

                if let last = lastLocation {
                    let delta = location.distance(from: last)
                    let dt = location.timestamp.timeIntervalSince(last.timestamp)
                    // Ignore les sauts GPS aberrants (> 15 m/s ≈ 54 km/h)
                    if delta > 0.5, dt > 0, delta / dt < 15 {
                        distanceMeters += delta
                        route.append(location.coordinate)
                        updatePace(delta: delta, dt: dt)
                    }
                } else {
                    route.append(location.coordinate)
                }
                lastLocation = location
            }
        }
    }

    private func updatePace(delta: Double, dt: TimeInterval) {
        recentSegments.append((delta, dt))
        // Garde ~les 200 derniers mètres
        var total = recentSegments.reduce(0) { $0 + $1.distance }
        while total > 200, recentSegments.count > 1 {
            total -= recentSegments.removeFirst().distance
        }
        let d = recentSegments.reduce(0) { $0 + $1.distance }
        let t = recentSegments.reduce(0) { $0 + $1.time }
        currentPaceSecPerKm = d > 0 ? t / (d / 1000) : 0
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .denied, .restricted: authorizationDenied = true
            default: authorizationDenied = false
            }
        }
    }
}
