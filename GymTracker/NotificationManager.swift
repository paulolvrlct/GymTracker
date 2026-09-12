import Foundation
import UserNotifications

/// Notifications locales — fonctionnent sur compte gratuit, sans serveur.
/// (Le push distant / APNs nécessite un compte payant + backend.)
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let restID = "rest-timer-finished"

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notifications autorisées : \(granted)")
        }
    }

    /// Notifie l'utilisateur à la fin du temps de repos (utile si l'app est en arrière-plan).
    func scheduleRestEnd(after seconds: Int, exerciseName: String) {
        cancelRestEnd()
        guard seconds > 0 else { return }

        // `String(localized:)` : un littéral affecté à une `String` n'est pas
        // extrait dans le catalogue, et la notification restait en français.
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Repos terminé 💪")
        content.body = String(localized: "C'est reparti ! \(exerciseName), série suivante.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: restID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelRestEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restID])
    }

    /// Rappel de séance à une date donnée (optionnel, ex : « demain 18h »).
    func scheduleWorkoutReminder(at date: Date, title: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Séance prévue")
        content.body = title
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "reminder-\(date.timeIntervalSince1970)",
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private let weeklyPrefix = "weekly-workout-"

    /// Programme des rappels hebdomadaires récurrents aux jours choisis.
    /// weekdays : 1 = dimanche … 7 = samedi (convention Apple).
    func scheduleWeeklyReminders(weekdays: Set<Int>, hour: Int, minute: Int) {
        clearWeeklyReminders()
        guard !weekdays.isEmpty else { return }
        for weekday in weekdays {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "C'est l'heure de bouger 💪")
            content.body = String(localized: "Ta séance t'attend dans LiftRun.")
            content.sound = .default

            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "\(weeklyPrefix)\(weekday)",
                                                content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func clearWeeklyReminders() {
        let ids = (1...7).map { "\(weeklyPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private let morningID = "morning-briefing"

    /// Le point du matin. Toujours le même identifiant : chaque programmation
    /// remplace la précédente, il n'y en a donc jamais plus d'une en attente.
    /// Niveau « passif » : visible à l'écran verrouillé et dans le centre de
    /// notifications, sans son ni allumage de l'écran.
    func scheduleMorningBriefing(at date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = .passive
        content.threadIdentifier = morningID

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: morningID, content: content, trigger: trigger))
    }

    func cancelMorningBriefing() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [morningID])
    }
}

// MARK: - Le point du matin

/// Une notification par jour au plus, à l'heure choisie : la forme prévue, la
/// séance conseillée et sa raison. Jamais de reproche ni de jours ratés.
///
/// Seule la **prochaine** occurrence est programmée, puis reprogrammée à chaque
/// ouverture de l'app avec l'historique à jour. Sans ouverture, celle qui est
/// déjà prévue part une fois, puis l'app se tait : on ne relance pas
/// quelqu'un qui fait une pause.
enum MorningBriefing {
    static let enabledKey = "morningBriefingEnabled"
    static let hourKey = "morningBriefingHour"
    static let minuteKey = "morningBriefingMinute"
    static let defaultHour = 8

    /// Prochaine occurrence de l'heure choisie, strictement après `now`.
    static func nextDate(after now: Date, hour: Int, minute: Int,
                         calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: now,
                          matching: DateComponents(hour: hour, minute: minute, second: 0),
                          matchingPolicy: .nextTime)
    }

    static func title(score: Int, action: String) -> String {
        String(localized: "Forme \(score) % · \(action)")
    }
}
