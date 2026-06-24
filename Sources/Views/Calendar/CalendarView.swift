import SwiftUI

struct CalendarView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var events: [CalendarEvent] = []
    @State private var selectedDayEvents: [CalendarEvent] = []
    @State private var isLoading: Bool = false
    @State private var showingNewEventSheet: Bool = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationSplitView {
            // Calendar Grid
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                calendarGrid
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        } detail: {
            // Events Sidebar
            VStack(spacing: 0) {
                eventsHeader
                if selectedDayEvents.isEmpty {
                    emptyEventsState
                } else {
                    eventsList
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .task {
            await loadEvents()
        }
        .onChange(of: currentMonth) { _, _ in
            Task { await loadEvents() }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task { await loadEventsForDay(newDate) }
        }
        .sheet(isPresented: $showingNewEventSheet) {
            if let userId = authManager.userId {
                NewEventSheet(
                    selectedDate: selectedDate,
                    userId: userId,
                    onEventCreated: {
                        Task { await loadEvents() }
                    }
                )
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(monthYearString)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(daysInMonth, id: \.self) { date in
                if let date = date {
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasEvents: hasEvents(on: date)
                    )
                    .onTapGesture {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }

    // MARK: - Events Header

    private var eventsHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weekdayDateString)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(dayMonthString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    showingNewEventSheet = true
                } label: {
                    Text("New Event")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.label))
                        )
                }
            }

            Divider()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Events List

    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(selectedDayEvents) { event in
                    EventRow(event: event)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty Events State

    private var emptyEventsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color(.tertiaryLabel))
            Text("No events")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: currentMonth)
    }

    private var weekdaySymbols: [String] {
        calendar.shortWeekdaySymbols
    }

    private var weekdayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale.current
        return formatter.string(from: selectedDate)
    }

    private var dayMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale.current
        return formatter.string(from: selectedDate)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }

        let firstOfMonth = monthInterval.start
        let lastOfMonth = monthInterval.end
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let numberOfDays = calendar.dateComponents([.day], from: firstOfMonth, to: lastOfMonth).day ?? 0

        var days: [Date?] = []

        // Add empty cells for days before the first day of the month
        for _ in 1..<(firstWeekday - 1) {
            days.append(nil)
        }

        // Add days of the month
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.startsAt, inSameDayAs: date) }
    }

    // MARK: - Data Loading

    private func loadEvents() async {
        guard let userId = authManager.userId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return }
            events = try await CalendarService.fetchEvents(
                for: userId,
                from: monthInterval.start,
                to: monthInterval.end
            )
            await loadEventsForDay(selectedDate)
        } catch {
            print("Failed to load events:", error)
        }
    }

    private func loadEventsForDay(_ date: Date) async {
        guard let userId = authManager.userId else { return }

        do {
            selectedDayEvents = try await CalendarService.fetchEvents(for: userId, on: date)
        } catch {
            print("Failed to load events for day:", error)
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color(.label))
                    .frame(width: 40, height: 40)
            }

            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)

                if hasEvents {
                    Circle()
                        .fill(isSelected ? Color(.systemBackground) : Color(.label))
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 40)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 12) {
                Text(timeString)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)

                if let description = event.description, !description.isEmpty {
                    Text("• \(description)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale.current

        if event.allDay {
            return "All day"
        } else if let endsAt = event.endsAt {
            let start = formatter.string(from: event.startsAt)
            let end = formatter.string(from: endsAt)
            return "\(start) - \(end)"
        } else {
            return formatter.string(from: event.startsAt)
        }
    }
}

// MARK: - New Event Sheet

struct NewEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDate: Date
    let userId: UUID
    let onEventCreated: () -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var allDay: Bool = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description)
                }

                Section {
                    Toggle("All day", isOn: $allDay)

                    if !allDay {
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    DatePicker("Date", selection: $startTime, displayedComponents: .date)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveEvent()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveEvent() async {
        do {
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
            let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

            let finalStartTime = calendar.date(byAdding: startComponents, to: startOfDay) ?? startOfDay
            let finalEndTime = allDay ? nil : calendar.date(byAdding: endComponents, to: startOfDay)

            _ = try await CalendarService.createEvent(
                userId: userId,
                title: title,
                description: description.isEmpty ? nil : description,
                startsAt: finalStartTime,
                endsAt: finalEndTime,
                allDay: allDay
            )

            onEventCreated()
            dismiss()
        } catch {
            print("Failed to create event:", error)
        }
    }
}
