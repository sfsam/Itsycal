import Foundation

extension WeekSnapshot {
    /// Synthetic data covering the same range as a real snapshot (this month
    /// and next month in whole weeks) for the widget gallery and offline
    /// renders; never requires calendar permission.
    static func preview(at date: Date, calendar: Calendar = WeekDates.calendar) -> WeekSnapshot {
        let weekStart = 1
        let thisWeek = WeekDates.weekStartDate(containing: date, weekStart: weekStart, calendar: calendar)
        let grid = WidgetPeriod.month.days(containing: date, weekStart: weekStart, calendar: calendar)
            + WidgetPeriod.month.days(containing: WidgetPeriod.month.next(after: date, calendar: calendar),
                                      weekStart: weekStart, calendar: calendar)
        // The two month grids always contain this week and next week as well.
        let first = grid[0], last = grid.last!
        // The first two weeks are hand-written for the week widget; the rest cycles.
        let weeks: [[String.LocalizationValue]] = [["Project review", "Weekly plan"], ["Design sync"], ["Team meeting", "Product review"],
                     ["Focus time", "Client call", "Design walkthrough", "Proposal review", "Feedback", "Reading"], ["Weekly review"], [], ["Plan next week"],
                     [], ["Requirements review"], [], ["Release"], [], ["Family dinner"], []]
        let cycle: [[String.LocalizationValue]] = [[], ["Team meeting"], ["Gym", "Book club"], [], ["Product review"], ["Design walkthrough", "Dentist", "Business trip"], [],
                     ["Family dinner", "Gym"], ["Weekly review"], [], ["Project review", "Team meeting", "Gym", "Book club", "Business trip"], ["Reading"]]
        var days: [String: [WeekEvent]] = [:]
        var day = first
        while day <= last {
            let offset = calendar.dateComponents([.day], from: thisWeek, to: day).day!
            let titles = (0..<weeks.count).contains(offset) ? weeks[offset] : cycle[(offset % cycle.count + cycle.count) % cycle.count]
            days[WeekDates.key(day, calendar: calendar)] = titles.enumerated().map { row, title in
                let start = calendar.date(bySettingHour: 8 + row * 2, minute: 30, second: 0, of: day)!
                return WeekEvent(id: "\(offset)-\(row)", title: String(localized: title), start: start.timeIntervalSince1970,
                                 end: start.addingTimeInterval(3600).timeIntervalSince1970,
                                 allDay: offset == 4 && row == 0, spansDay: false, startsHere: true,
                                 endsHere: false, continues: false,
                                 color: row.isMultiple(of: 2) ? [0.25, 0.48, 0.75] : [0.35, 0.62, 0.49])
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return WeekSnapshot(version: 2, generatedAt: date.timeIntervalSince1970,
                            timeZone: calendar.timeZone.identifier, start: first.timeIntervalSince1970,
                            end: calendar.date(byAdding: .day, value: 1, to: last)!.timeIntervalSince1970,
                            status: "ready", weekStart: weekStart, days: days)
    }
}
