import SwiftUI

// MARK: - Design Tokens

private enum DS {
    // Typography
    static let fontDisplay = "Canela-Light"          // Elegant editorial serif for month name
    static let fontMono    = "SF Mono"               // Monospaced for day numbers

    // Palette
    static let ink         = Color(hex: "#0D0D0D")
    static let inkFaint    = Color(hex: "#0D0D0D").opacity(0.08)
    static let ghost       = Color(hex: "#F7F6F3")   // Warm off-white background
    static let surface     = Color(hex: "#FFFFFF")
    static let subtext     = Color(hex: "#9A9898")
    static let accent      = Color(hex: "#C8A97A")   // Warm amber — event dot / selection ring
    static let accentSoft  = Color(hex: "#C8A97A").opacity(0.15)

    // Motion
    static let springSnappy    = Animation.spring(response: 0.32, dampingFraction: 0.72)
    static let springGentle    = Animation.spring(response: 0.44, dampingFraction: 0.82)
    static let easeQuick       = Animation.easeOut(duration: 0.18)
}

// MARK: - CalendarView

struct CalendarView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var events: [CalendarEvent] = []
    @State private var selectedDayEvents: [CalendarEvent] = []
    @State private var isLoading: Bool = false
    @State private var showingNewEventSheet: Bool = false
    @State private var monthTransitionDirection: Int = 0  // -1 left, 1 right
    @State private var monthID: UUID = UUID()             // Triggers re-render on month change

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: Calendar Panel ──────────────────────────────────────
            calendarPanel
                .frame(maxWidth: 420)

            // Divider
            Rectangle()
                .fill(DS.inkFaint)
                .frame(width: 1)
                .ignoresSafeArea()

            // ── Right: Events Panel ───────────────────────────────────────
            eventsPanel
                .frame(maxWidth: .infinity)
        }
        .background(DS.ghost.ignoresSafeArea())
        .task { await loadEvents() }
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

    // MARK: Calendar Panel

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            calendarHeader
                .padding(.horizontal, 32)
                .padding(.top, 52)
                .padding(.bottom, 28)

            weekdayRow
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            Rectangle()
                .fill(DS.inkFaint)
                .frame(height: 1)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

            calendarGrid
                .padding(.horizontal, 24)
                .id(monthID)  // Animate on month change

            Spacer()
        }
        .background(DS.ghost)
    }

    // MARK: Calendar Header

    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(yearString)
                .font(.system(size: 11, weight: .medium))
                .tracking(3)
                .foregroundStyle(DS.subtext)

            HStack(alignment: .firstTextBaseline) {
                // Display font for month — falls back gracefully
                Text(monthString)
                    .font(.custom(DS.fontDisplay, size: 44).weight(.light))
                    .foregroundStyle(DS.ink)
                    .contentTransition(.numericText())
                    .animation(DS.springGentle, value: currentMonth)

                Spacer()

                HStack(spacing: 4) {
                    monthNavButton(systemName: "chevron.left") {
                        advanceMonth(by: -1)
                    }
                    monthNavButton(systemName: "chevron.right") {
                        advanceMonth(by: 1)
                    }
                }
            }
        }
    }

    private func monthNavButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.ink.opacity(0.55))
                .frame(width: 36, height: 36)
                .background(DS.inkFaint, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Weekday Row

    private var weekdayRow: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym.prefix(1))  // Single character — ultra minimal
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(DS.subtext)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Calendar Grid

    private var calendarGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: cols, spacing: 0) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                if let date {
                    CalDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasEvents: hasEvents(on: date)
                    )
                    .onTapGesture {
                        withAnimation(DS.springSnappy) {
                            selectedDate = date
                        }
                    }
                    .transition(.opacity)
                    .animation(
                        DS.springGentle.delay(Double(index) * 0.012),
                        value: monthID
                    )
                } else {
                    Color.clear.frame(height: 52)
                }
            }
        }
    }

    // MARK: Events Panel

    private var eventsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            eventsPanelHeader
                .padding(.horizontal, 40)
                .padding(.top, 52)
                .padding(.bottom, 28)

            if isLoading {
                loadingState
            } else if selectedDayEvents.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(selectedDayEvents.enumerated()), id: \.element.id) { index, event in
                            CalEventRow(event: event)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .animation(
                                    DS.springGentle.delay(Double(index) * 0.05),
                                    value: selectedDate
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }

            Spacer()
        }
        .background(DS.surface)
    }

    private var eventsPanelHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekdayString.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(DS.subtext)
                    .animation(DS.easeQuick, value: selectedDate)

                Text(dayString)
                    .font(.system(size: 52, weight: .thin, design: .default))
                    .foregroundStyle(DS.ink)
                    .contentTransition(.numericText())
                    .animation(DS.springSnappy, value: selectedDate)
            }

            Spacer()

            // New Event button
            Button {
                withAnimation(DS.springSnappy) {
                    showingNewEventSheet = true
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("New Event")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.3)
                }
                .foregroundStyle(DS.ghost)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(DS.ink, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            // Thin cross grid pattern using SF Symbol
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(DS.inkFaint.opacity(0.6))
            Text("Nothing scheduled")
                .font(.system(size: 14, weight: .regular))
                .tracking(0.2)
                .foregroundStyle(DS.subtext)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(DS.subtext)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var monthString: String {
        currentMonth.formatted(.dateTime.month(.wide).locale(.current))
    }

    private var yearString: String {
        currentMonth.formatted(.dateTime.year().locale(.current))
    }

    private var weekdayString: String {
        selectedDate.formatted(.dateTime.weekday(.wide).locale(.current))
    }

    private var dayString: String {
        selectedDate.formatted(.dateTime.day().locale(.current))
    }

    private var weekdaySymbols: [String] {
        calendar.shortWeekdaySymbols
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let lastOfMonth  = monthInterval.end
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let numberOfDays = calendar.dateComponents([.day], from: firstOfMonth, to: lastOfMonth).day ?? 0

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in 0..<numberOfDays {
            days.append(calendar.date(byAdding: .day, value: day, to: firstOfMonth))
        }
        return days
    }

    private func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.startsAt, inSameDayAs: date) }
    }

    private func advanceMonth(by value: Int) {
        withAnimation(DS.springGentle) {
            currentMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) ?? currentMonth
            monthID = UUID()
        }
    }

    // MARK: - Data Loading

    private func loadEvents() async {
        guard let userId = authManager.userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return }
            events = try await CalendarService.fetchEvents(for: userId, from: monthInterval.start, to: monthInterval.end)
            await loadEventsForDay(selectedDate)
        } catch {
            print("Failed to load events:", error)
        }
    }

    private func loadEventsForDay(_ date: Date) async {
        guard let userId = authManager.userId else { return }
        do {
            withAnimation(DS.springGentle) {
                selectedDayEvents = []  // Clear first to trigger stagger animation
            }
            let fetched = try await CalendarService.fetchEvents(for: userId, on: date)
            withAnimation(DS.springGentle) {
                selectedDayEvents = fetched
            }
        } catch {
            print("Failed to load events for day:", error)
        }
    }
}

// MARK: - CalDayCell

struct CalDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool

    @State private var isPressed: Bool = false

    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .fill(DS.ink)
                    .frame(width: 42, height: 42)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            // Today ring
            if isToday && !isSelected {
                Circle()
                    .strokeBorder(DS.accent, lineWidth: 1.5)
                    .frame(width: 40, height: 40)
                    .transition(.scale.combined(with: .opacity))
            }

            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 15, weight: isSelected || isToday ? .medium : .light, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(
                        isSelected ? DS.ghost :
                        isToday    ? DS.accent :
                                     DS.ink.opacity(0.85)
                    )
                    .animation(DS.easeQuick, value: isSelected)

                // Event presence dot
                Circle()
                    .fill(isSelected ? DS.ghost.opacity(0.6) : DS.accent)
                    .frame(width: 3.5, height: 3.5)
                    .opacity(hasEvents ? 1 : 0)
                    .scaleEffect(hasEvents ? 1 : 0.3)
                    .animation(DS.springSnappy, value: hasEvents)
            }
        }
        .frame(height: 52)
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .animation(DS.springSnappy, value: isPressed)
        ._onButtonGesture(pressing: { p in isPressed = p }, perform: {})
        .contentShape(Rectangle())
    }

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - CalEventRow

struct CalEventRow: View {
    let event: CalendarEvent
    @State private var appeared: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                if event.allDay {
                    Text("ALL DAY")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(DS.subtext)
                } else {
                    Text(startTimeString)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(DS.ink.opacity(0.75))
                    if let end = event.endsAt {
                        Text(timeString(from: end))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(DS.subtext)
                    }
                }
            }
            .frame(width: 60, alignment: .trailing)
            .padding(.top, 18)

            // Divider line with dot
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                Circle()
                    .fill(DS.accent)
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(DS.inkFaint)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .padding(.bottom, 4)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.ink)
                    .padding(.top, 14)

                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DS.subtext)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, 20)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 12)
        .onAppear {
            withAnimation(DS.springGentle) {
                appeared = true
            }
        }
    }

    private var startTimeString: String { timeString(from: event.startsAt) }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }
}

// MARK: - NewEventSheet (redesigned)

struct NewEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDate: Date
    let userId: UUID
    let onEventCreated: () -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var allDay: Bool = false
    @State private var isSaving: Bool = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Title", systemImage: "")
                            .fieldLabel()
                        TextField("Event name", text: $title)
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(DS.ink)
                            .tint(DS.accent)
                            .padding(.bottom, 8)
                        Divider().background(DS.inkFaint)
                    }
                    .padding(.top, 40)

                    // Description field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .fieldLabel()
                        TextField("Add notes", text: $description, axis: .vertical)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(DS.ink)
                            .tint(DS.accent)
                            .lineLimit(3...6)
                            .padding(.bottom, 8)
                        Divider().background(DS.inkFaint)
                    }
                    .padding(.top, 32)

                    // All day toggle
                    HStack {
                        Text("All day")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.ink)
                        Spacer()
                        Toggle("", isOn: $allDay.animation(DS.springSnappy))
                            .tint(DS.ink)
                            .labelsHidden()
                    }
                    .padding(.vertical, 20)
                    Divider().background(DS.inkFaint)

                    if !allDay {
                        Group {
                            sheetDateRow(label: "Start", selection: $startTime)
                            Divider().background(DS.inkFaint)
                            sheetDateRow(label: "End", selection: $endTime)
                            Divider().background(DS.inkFaint)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
            .background(DS.surface.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundStyle(DS.subtext)
                }
                ToolbarItem(placement: .principal) {
                    Text("New Event")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(DS.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(DS.ink)
                    } else {
                        Button("Save") {
                            Task { await saveEvent() }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(title.isEmpty ? DS.subtext : DS.ink)
                        .disabled(title.isEmpty)
                    }
                }
            }
        }
    }

    private func sheetDateRow(label: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(DS.ink)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(DS.accent)
        }
        .padding(.vertical, 14)
    }

    private func saveEvent() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let sc = calendar.dateComponents([.hour, .minute], from: startTime)
            let ec = calendar.dateComponents([.hour, .minute], from: endTime)
            let finalStart = calendar.date(byAdding: sc, to: startOfDay) ?? startOfDay
            let finalEnd   = allDay ? nil : calendar.date(byAdding: ec, to: startOfDay)

            _ = try await CalendarService.createEvent(
                userId: userId,
                title: title,
                description: description.isEmpty ? nil : description,
                startsAt: finalStart,
                endsAt: finalEnd,
                allDay: allDay
            )
            onEventCreated()
            dismiss()
        } catch {
            print("Failed to create event:", error)
        }
    }
}

// MARK: - Utility Extensions

extension View {
    func fieldLabel() -> some View {
        self.font(.system(size: 10, weight: .semibold))
            .tracking(2)
            .foregroundStyle(DS.subtext)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
