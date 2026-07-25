//
//  NotificationManager.swift
//  TyreTrack
//
//  Real local notifications via UNUserNotificationCenter.
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Ask for permission. Completion returns whether granted.
    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// Schedule a reminder. Uses the reminder's own id so it can be cancelled precisely.
    func schedule(_ reminder: TyreReminder, vehicleTitle: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Tyre Track — \(reminder.type.label)"
        var bodyText = reminder.type.body
        if let t = vehicleTitle, !t.isEmpty { bodyText += "  (\(t))" }
        content.body = bodyText
        content.sound = .default

        let cal = Calendar.current
        var comps: DateComponents
        var trigger: UNCalendarNotificationTrigger

        if reminder.repeats {
            // Repeat monthly at the chosen day/time.
            comps = cal.dateComponents([.day, .hour, .minute], from: reminder.date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        } else {
            comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }

        let request = UNNotificationRequest(identifier: reminder.id.uuidString,
                                            content: content,
                                            trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancel(_ reminder: TyreReminder) {
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Re-sync all reminders (used after toggling the master switch or editing).
    func resync(reminders: [TyreReminder], enabled: Bool, titleFor: (UUID?) -> String?) {
        cancelAll()
        guard enabled else { return }
        for r in reminders where r.enabled {
            schedule(r, vehicleTitle: titleFor(r.vehicleID))
        }
    }
}
