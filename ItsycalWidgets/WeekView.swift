import SwiftUI

struct WeekView: View {
    private let state: PeriodState
    private let compact: Bool
    private let calendar = WeekDates.calendar
    private var date: Date { state.now }

    /// `shown` is any date inside the week to display.
    init(date: Date, shown: Date, snapshot: WeekSnapshot?, compact: Bool) {
        state = PeriodState(.week, now: date, shown: shown, snapshot: snapshot, calendar: WeekDates.calendar)
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            PeriodHeader(state: state, compact: compact, calendar: calendar)
            columns
        }
        .padding(compact ? 8 : 16)
    }

    private var columns: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(state.dates.enumerated()), id: \.offset) { index, day in
                    dayColumn(day, events: state.dayEvents[index],
                              capacity: WeekDates.capacity(height: geometry.size.height, compact: compact))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .overlay(alignment: .leading) {
                            if index > 0 {
                                Rectangle().fill(Color.primary.opacity(0.07))
                                    .frame(width: 0.5).padding(.top, compact ? 32 : 36)
                            }
                        }
                }
            }
            .periodOverlays(state, calendar: calendar)
        }
    }

    private func dayColumn(_ day: Date, events: [WeekEvent], capacity: Int) -> some View {
        let today = calendar.isDate(day, inSameDayAs: date)
        let past = day < calendar.startOfDay(for: date)
        let hidden = max(0, events.count - capacity)
        let link = WeekDates.link(day, calendar: calendar)
        return VStack(alignment: .leading, spacing: compact ? 4 : 10) {
            Link(destination: link) {
                let layout = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 1))
                                     : AnyLayout(HStackLayout(spacing: 4))
                layout {
                    Text(WeekDates.weekdayLabel(day, calendar: calendar))
                        .font(.system(size: compact ? 8 : 10, weight: today ? .semibold : .regular))
                        .foregroundStyle(today ? Color.itsycalAccent : Color.secondary)
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: compact ? 12 : 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(today ? .white : Color.primary)
                        .frame(minWidth: compact ? 20 : 26, minHeight: compact ? 17 : 24)
                        .background {
                            if today { RoundedRectangle(cornerRadius: compact ? 5 : 7).fill(Color.itsycalAccent) }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: compact ? 28 : 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(today ? Text("\(day.formatted(date: .complete, time: .omitted)), today") : Text(day.formatted(date: .complete, time: .omitted)))

            if state.issue == nil {
                VStack(alignment: .leading, spacing: 0) {
                    if events.isEmpty {
                        Text("No events").font(.system(size: compact ? 9 : 10)).foregroundStyle(.tertiary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    } else {
                        ForEach(Array(events.prefix(capacity).enumerated()), id: \.offset) { _, event in
                            Link(destination: link) { eventRow(event) }.buttonStyle(.plain)
                        }
                        if hidden > 0 {
                            Link(destination: link) {
                                Text("\(hidden) more")
                                    .font(.system(size: compact ? 8 : 10, weight: .medium))
                                    .foregroundStyle(today ? Color.itsycalAccent : Color.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: compact ? 14 : 18, alignment: .topLeading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 3 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(past ? 0.5 : 1)
    }

    private func eventRow(_ event: WeekEvent) -> some View {
        HStack(alignment: .top, spacing: compact ? 3 : 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(event.tint)
                .frame(width: compact ? 1.5 : 2, height: compact ? 19 : 23)
                .padding(.top, compact ? 1 : 2)
            ViewThatFits(in: .horizontal) {
                if !compact {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(event.timeLabel).font(.system(size: 9)).foregroundStyle(.secondary)
                        Text(event.title).font(.system(size: 10))
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: compact ? 0 : 2) {
                    Text(event.timeLabel).font(.system(size: compact ? 8 : 9)).foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(event.title).font(.system(size: 10))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: WeekDates.eventPitch(compact: compact), alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
