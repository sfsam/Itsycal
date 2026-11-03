import Foundation

struct WeekEvent: Codable {
    let id: String
    let title: String
    let start: TimeInterval
    let end: TimeInterval
    let allDay: Bool
    let spansDay: Bool
    let startsHere: Bool
    let endsHere: Bool
    let continues: Bool
    let color: [Double]

    var timeLabel: String {
        if allDay { return String(localized: "All day") }
        if spansDay && !startsHere { return String(localized: "Ongoing") }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if endsHere { return "→ " + formatter.string(from: Date(timeIntervalSince1970: end)) }
        let time = formatter.string(from: Date(timeIntervalSince1970: start))
        return continues ? time + " →" : time
    }
}

enum WidgetShared {
    static var group: String? { Bundle.main.object(forInfoDictionaryKey: "ItsycalAppGroup") as? String }
}

/// The span a widget shows: the week widget or the month widget.
enum WidgetPeriod: String, CaseIterable, Sendable { // AppEnum conformance: WeekIntent.swift
    case week, month

    var kind: String { self == .week ? "ItsycalWeek" : "ItsycalMonth" }

    /// Every day the widget draws for the period containing `date`.
    func days(containing date: Date, weekStart: Int, calendar: Calendar) -> [Date] {
        switch self {
        case .week: WeekDates.days(containing: date, weekStart: weekStart, calendar: calendar)
        case .month: MonthDates.grid(containing: date, weekStart: weekStart, calendar: calendar).flatMap { $0 }
        }
    }

    func next(after date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: self == .week ? .weekOfYear : .month, value: 1, to: date)!
    }

    func isSame(_ date: Date, as other: Date, weekStart: Int, calendar: Calendar) -> Bool {
        switch self {
        case .week: WeekDates.weekStartDate(containing: date, weekStart: weekStart, calendar: calendar)
            == WeekDates.weekStartDate(containing: other, weekStart: weekStart, calendar: calendar)
        case .month: calendar.isDate(date, equalTo: other, toGranularity: .month)
        }
    }
}

struct WeekSnapshot: Codable {
    let version: Int
    let generatedAt: TimeInterval
    let timeZone: String
    let start: TimeInterval
    let end: TimeInterval
    let status: String
    let weekStart: Int
    let days: [String: [WeekEvent]]

    static func load() -> WeekSnapshot? {
        guard let group = WidgetShared.group,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
              let data = try? Data(contentsOf: container.appendingPathComponent("week.json")),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data),
              snapshot.version == 2 else { return nil }
        return snapshot
    }

    /// Why the period containing `shown` cannot be displayed, or nil when it can.
    func message(for period: WidgetPeriod, containing shown: Date, calendar: Calendar) -> String? {
        if status == "permission" { return String(localized: "Open Itsycal to allow calendar access") }
        if status == "calendars" { return String(localized: "Choose calendars to show in Itsycal") }
        guard status == "ready" else { return String(localized: "Open Itsycal to update events") }
        guard (0...6).contains(weekStart) else { return String(localized: "Open Itsycal to update events") }
        if timeZone != calendar.timeZone.identifier { return String(localized: "Time zone changed. Open Itsycal to update events") }
        let shownDays = period.days(containing: shown, weekStart: weekStart, calendar: calendar)
        let after = calendar.date(byAdding: .day, value: 1, to: shownDays.last!)!
        if shownDays[0].timeIntervalSince1970 < start || after.timeIntervalSince1970 > end {
            return period == .week ? String(localized: "Open Itsycal to load this week") : String(localized: "Open Itsycal to load this month")
        }
        // Missing buckets mean incomplete data, never an empty calendar.
        if shownDays.contains(where: { days[WeekDates.key($0, calendar: calendar)] == nil }) {
            return String(localized: "Open Itsycal to update events")
        }
        return nil
    }
}

/// Next-week or next-month view chosen in a widget. Each period has its own
/// state, shared by that widget's instances, and expires back to the current one.
struct PeriodNavigation {
    static let idle: TimeInterval = 15 * 60

    let target: Date // An instant inside the shown period.
    let until: Date

    func shown(at date: Date) -> Date { date < until ? target : date }

    static func next(_ period: WidgetPeriod, from now: Date, calendar: Calendar) -> PeriodNavigation {
        PeriodNavigation(target: period.next(after: now, calendar: calendar), until: now.addingTimeInterval(idle))
    }

    /// The next period is offered only when the snapshot can display all of it.
    static func canShowNext(_ period: WidgetPeriod, snapshot: WeekSnapshot?, today: Date, calendar: Calendar) -> Bool {
        guard let snapshot else { return false }
        return snapshot.message(for: period, containing: period.next(after: today, calendar: calendar),
                                calendar: calendar) == nil
    }

    // One key per period holding [target, until], so readers never see half an update.
    private static func key(_ period: WidgetPeriod) -> String { "navigation.\(period.rawValue)" }
    private static var defaults: UserDefaults? { WidgetShared.group.flatMap(UserDefaults.init(suiteName:)) }

    static func load(_ period: WidgetPeriod) -> PeriodNavigation? {
        guard let value = defaults?.array(forKey: key(period)) as? [TimeInterval], value.count == 2 else { return nil }
        return PeriodNavigation(target: Date(timeIntervalSince1970: value[0]), until: Date(timeIntervalSince1970: value[1]))
    }

    /// nil returns to the current period.
    static func store(_ navigation: PeriodNavigation?, for period: WidgetPeriod) {
        if let navigation {
            defaults?.set([navigation.target.timeIntervalSince1970, navigation.until.timeIntervalSince1970],
                          forKey: key(period))
        } else {
            defaults?.removeObject(forKey: key(period))
        }
    }
}

enum WeekDates {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func weekStartDate(containing date: Date, weekStart: Int, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let start = min(max(weekStart, 0), 6)
        let offset = (calendar.component(.weekday, from: day) - 1 - start + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day)!
    }

    static func days(containing date: Date, weekStart: Int, calendar: Calendar) -> [Date] {
        let first = weekStartDate(containing: date, weekStart: weekStart, calendar: calendar)
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: first)! }
    }


    static func key(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func link(_ date: Date, calendar: Calendar) -> URL {
        URL(string: "itsycal://date/\(key(date, calendar: calendar))?widget=1")!
    }

    /// Abbreviated weekday in the user's language (e.g. "Mon").
    static func weekdayLabel(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    static func eventPitch(compact: Bool) -> Double { compact ? 25 : 36 }
    static func reservedHeight(compact: Bool) -> Double {
        compact ? 46 : 54 // Date, gap and overflow; header lives outside the columns.
    }

    static func capacity(height: Double, compact: Bool = true) -> Int {
        min(4, max(0, Int((height - reservedHeight(compact: compact)) / eventPitch(compact: compact))))
    }

    /// Now, each of the next 14 local midnights and, if later than now, the
    /// moment the next-period view expires.
    static func timelineDates(from date: Date, calendar: Calendar, navigation: PeriodNavigation? = nil) -> [Date] {
        let midnight = calendar.startOfDay(for: date)
        var dates = [date] + (1...14).map { calendar.date(byAdding: .day, value: $0, to: midnight)! }
        if let until = navigation?.until, until > date { dates.append(until) }
        return dates.sorted()
    }
}

enum MonthDates {
    /// Whole weeks covering the month that contains `date` (4–6 rows).
    static func grid(containing date: Date, weekStart: Int, calendar: Calendar) -> [[Date]] {
        let month = calendar.dateInterval(of: .month, for: date)!
        var day = WeekDates.weekStartDate(containing: month.start, weekStart: weekStart, calendar: calendar)
        var weeks: [[Date]] = []
        while day < month.end {
            weeks.append((0..<7).map { calendar.date(byAdding: .day, value: $0, to: day)! })
            day = calendar.date(byAdding: .day, value: 7, to: day)!
        }
        return weeks
    }
}

/// Month cell geometry shared by MonthView and its capacity rule.
enum MonthLayout {
    static let topInset: Double = 2
    static let numberHeight: Double = 17
    static let numberGap: Double = 1
    static let chipHeight: Double = 11

    /// Event chips that fit under the date in a cell of the given height.
    static func eventRows(cellHeight: Double) -> Int {
        max(0, Int((cellHeight - topInset - numberHeight - numberGap) / chipHeight))
    }
}
