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
        let events: [CalendarEvent] = try await supabase
            .from(table)
            .select()
            .gte("starts_at", value: startDate)
            .lte("starts_at", value: endDate)
            .eq("user_id", value: userId)
            .order("starts_at", ascending: true)
            .execute()
            .value
        return events
    }

    static func fetchEvents(for userId: UUID, on date: Date) async throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let events: [CalendarEvent] = try await supabase
            .from(table)
            .select()
            .gte("starts_at", value: startOfDay)
            .lt("starts_at", value: endOfDay)
            .eq("user_id", value: userId)
            .order("starts_at", ascending: true)
            .execute()
            .value
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
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "title": .string(title),
            "description": description != nil ? .string(description!) : .null,
            "starts_at": .string(iso.string(from: startsAt)),
            "ends_at": endsAt != nil ? .string(iso.string(from: endsAt!)) : .null,
            "all_day": .integer(allDay ? 1 : 0)
        ]

        let createdEvent: CalendarEvent = try await supabase
            .from(table)
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

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
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var updates: [String: AnyJSON] = [:]
        updates["updated_at"] = .string(iso.string(from: Date()))

        if let title = title { updates["title"] = .string(title) }
        if let description = description { updates["description"] = .string(description) }
        if let startsAt = startsAt { updates["starts_at"] = .string(iso.string(from: startsAt)) }
        if let endsAt = endsAt { updates["ends_at"] = .string(iso.string(from: endsAt)) }
        if let allDay = allDay { updates["all_day"] = .integer(allDay ? 1 : 0) }

        let updatedEvent: CalendarEvent = try await supabase
            .from(table)
            .update(updates)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value

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
