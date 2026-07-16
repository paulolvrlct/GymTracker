import Foundation
import ActivityKit

// ⚠️ Ce fichier doit être ajouté aux DEUX targets : l'app ET la widget extension.
// Il définit les données affichées dans la Dynamic Island et sur l'écran verrouillé.

// MARK: - Timer de repos (musculation)

struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var endDate: Date        // le widget décompte tout seul jusqu'à cette date
        var totalSeconds: Int
    }
    var workoutName: String
}

// MARK: - Course (running)

struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceMeters: Double
        var elapsedSeconds: Int
        var paceSecPerKm: Double

        var distanceKmText: String {
            String(format: "%.2f", distanceMeters / 1000)
        }
        var paceText: String {
            guard paceSecPerKm > 0, paceSecPerKm.isFinite else { return "-'--\"" }
            let m = Int(paceSecPerKm) / 60, s = Int(paceSecPerKm) % 60
            return String(format: "%d'%02d\"", m, s)
        }
        var durationText: String {
            let h = elapsedSeconds / 3600, m = (elapsedSeconds % 3600) / 60, s = elapsedSeconds % 60
            return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                         : String(format: "%d:%02d", m, s)
        }
    }
    var startedAt: Date
}
