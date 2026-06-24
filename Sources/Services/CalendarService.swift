import Foundation
import Supabase

enum CalendarError: LocalizedError {
    case notAuthenticated
    case fetchFailed
    case createFailed
    case updateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User not authenticated"
        case .fetchFailed: return "Failed to fetch events"
        case .createFailed: return "Failed to create event"
        case .updateFailed: return "Failed to update event"
        case .deleteFailed: return "Failed to delete event"
        }
    }
}

struct CalendarService {
    private static let table = "calendar_events"

    static func fetchEvents(for userId: UUID, from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        let response = try await supabase
            .from(table)
            .select()
            .gte("starts_at", value: startDate)
            .lte("starts_at", value: endDate)
            .eq("user_id", value: userId)
            .order("starts_at", ascending: true)
            .execute()

        let events: [CalendarEvent] = try response.value
        return events
    }

    static func fetchEvents(for userId: UUID, on date: Date) async throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let response = try await supabase
            .from(table)
            .select()
            .gte("starts_at", value: startOfDay)
            .lt("starts_at", value: endOfDay)
            .eq("user_id", value: userId)
            .order("starts_at", ascending: true)
            .execute()

        let events: [CalendarEvent] = try response.value
        return events
    }

    static func createEvent(
        userId: UUID,
        title: String,
        description: String?,
        startsAt: Date,
        endsAt: Date?,
        allDay: Bool
    ) async throws -> CalendarEvent {
        let event = CalendarEvent(
            id: UUID(),
            userId: userId,
            title: title,
            description: description,
            startsAt: startsAt,
            endsAt: endsAt,
            allDay: allDay,
            createdAt: Date(),
            updatedAt: Date()
        )

        let response = try await supabase
            .from(table)
            .insert(event)
            .select()
            .single()
            .execute()

        let createdEvent: CalendarEvent = try response.value

        // Schedule notification
        NotificationManager.shared.scheduleNotification(for: createdEvent)

        return createdEvent
    }

    static func updateEvent(
        id: UUID,
        title: String?,
        description: String?,
        startsAt: Date?,
        endsAt: Date?,
        allDay: Bool?
    ) async throws -> CalendarEvent {
        var updates: [String: Any] = [:]
        updates["updated_at"] = Date()

        if let title = title { updates["title"] = title }
        if let description = description { updates["description"] = description }
        if let startsAt = startsAt { updates["starts_at"] = startsAt }
        if let endsAt = endsAt { updates["ends_at"] = endsAt }
        if let allDay = allDay { updates["all_day"] = allDay }

        let response = try await supabase
            .from(table)
            .update(updates)
            .eq("id", value: id)
            .select()
            .single()
            .execute()

        let updatedEvent: CalendarEvent = try response.value

        // Reschedule notification
        NotificationManager.shared.scheduleNotification(for: updatedEvent)

        return updatedEvent
    }

    static func deleteEvent(id: UUID) async throws {
        // Cancel notification before deleting
        NotificationManager.shared.cancelNotification(for: id)

        try await supabase
            .from(table)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
