import SwiftUI

/// Extra-large month widget: whole weeks of the shown month, each day with as
/// many events as fit and a +N overflow beside the date.
struct MonthView: View {
    private let state: PeriodState
    private let calendar = WeekDates.calendar

    /// `shown` is any date inside the month to display.
    init(date: Date, shown: Date, snapshot: WeekSnapshot?) {
        state = PeriodState(.month, now: date, shown: shown, snapshot: snapshot, calendar: WeekDates.calendar)
    }

    /// Index ranges into `state.dates`, one per week row.
    private var weeks: [Range<Int>] {
        stride(from: 0, to: state.dates.count, by: 7).map { $0..<$0 + 7 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PeriodHeader(state: state, compact: false, calendar: calendar)
            weekdayRow
            grid.periodOverlays(state, calendar: calendar)
        }
        .padding(16)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(state.dates.prefix(7), id: \.self) { day in
                Text(WeekDates.weekdayLabel(day, calendar: calendar))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 5)
            }
        }
    }

    private var grid: some View {
        GeometryReader { geometry in
            let rowHeight = geometry.size.height / CGFloat(weeks.count)
            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { index in
                            cell(state.dates[index], events: state.dayEvents[index], height: rowHeight)
                        }
                    }
                    .frame(height: rowHeight)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func cell(_ day: Date, events: [WeekEvent], height: CGFloat) -> some View {
        let inMonth = calendar.isDate(day, equalTo: state.shown, toGranularity: .month)
        let past = day < calendar.startOfDay(for: state.now)
        let rows = state.issue == nil ? MonthLayout.eventRows(cellHeight: height) : 0
        let visible = min(events.count, rows)
        let hidden = state.issue == nil ? events.count - visible : 0
        return Link(destination: WeekDates.link(day, calendar: calendar)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    dayNumber(day)
                    Spacer(minLength: 0)
                    if hidden > 0 {
                        Text("+\(hidden)").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, MonthLayout.numberGap)
                ForEach(Array(events.prefix(visible).enumerated()), id: \.offset) { _, event in
                    chip(event)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.top, MonthLayout.topInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(!inMonth ? 0.28 : (past ? 0.45 : 1))
    }

    private func dayNumber(_ day: Date) -> some View {
        let today = calendar.isDate(day, inSameDayAs: state.now)
        return Text("\(calendar.component(.day, from: day))")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(today ? .white : Color.primary)
            .frame(minWidth: 22, minHeight: MonthLayout.numberHeight)
            .background { if today { RoundedRectangle(cornerRadius: 5).fill(Color.itsycalAccent) } }
            .accessibilityLabel(today ? Text("\(day.formatted(date: .complete, time: .omitted)), today") : Text(day.formatted(date: .complete, time: .omitted)))
    }

    /// All-day events as a tinted block, timed events as a colour bar and title.
    private func chip(_ event: WeekEvent) -> some View {
        HStack(spacing: 3) {
            if !event.allDay {
                RoundedRectangle(cornerRadius: 1).fill(event.tint).frame(width: 2, height: 9)
            }
            Text(event.title).font(.system(size: 9)).lineLimit(1)
        }
        .padding(.horizontal, event.allDay ? 4 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: MonthLayout.chipHeight)
        .background {
            if event.allDay { RoundedRectangle(cornerRadius: 3).fill(event.tint.opacity(0.25)) }
        }
    }
}
