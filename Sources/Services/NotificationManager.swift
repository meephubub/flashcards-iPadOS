import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    func scheduleNotification(for event: CalendarEvent) {
        let center = UNUserNotificationCenter.current()
        
        // Cancel any existing notification for this event
        center.removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])
        
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.description ?? "Event starting soon"
        content.sound = .default
        content.badge = 1
        
        // Schedule notification 15 minutes before the event
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -15, to: event.startsAt) ?? event.startsAt
        
        // Only schedule if the trigger date is in the future
        guard triggerDate > Date() else { return }
        
        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func cancelNotification(for eventId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [eventId.uuidString])
    }

    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }

    func scheduleNotifications(for events: [CalendarEvent]) {
        for event in events {
            scheduleNotification(for: event)
        }
    }
}
