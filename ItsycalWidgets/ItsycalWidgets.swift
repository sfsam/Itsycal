import SwiftUI
import WidgetKit

struct PeriodEntry: TimelineEntry {
    let date: Date
    let shown: Date // A date inside the displayed week or month.
    let snapshot: WeekSnapshot?
}

/// One provider for both widgets; they differ only in which navigation state they read.
struct PeriodProvider: TimelineProvider {
    let period: WidgetPeriod

    func placeholder(in context: Context) -> PeriodEntry {
        PeriodEntry(date: .now, shown: .now, snapshot: .preview(at: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (PeriodEntry) -> Void) {
        let now = Date()
        if context.isPreview { return completion(PeriodEntry(date: now, shown: now, snapshot: .preview(at: now))) }
        completion(PeriodEntry(date: now, shown: PeriodNavigation.load(period)?.shown(at: now) ?? now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PeriodEntry>) -> Void) {
        let now = Date()
        let snapshot = WeekSnapshot.load()
        let navigation = PeriodNavigation.load(period)
        let entries = WeekDates.timelineDates(from: now, calendar: WeekDates.calendar, navigation: navigation)
            .map { PeriodEntry(date: $0, shown: navigation?.shown(at: $0) ?? $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600))))
    }
}

private struct WeekWidgetContent: View {
    let entry: PeriodEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WeekView(date: entry.date, shown: entry.shown, snapshot: entry.snapshot, compact: family == .systemMedium)
    }
}

struct ItsycalWeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetPeriod.week.kind, provider: PeriodProvider(period: .week)) { entry in
            WeekWidgetContent(entry: entry)
                .privacySensitive()
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Week Calendar")
        .description("Your events for each day of the week.")
        .supportedFamilies([.systemMedium, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

struct ItsycalMonthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetPeriod.month.kind, provider: PeriodProvider(period: .month)) { entry in
            MonthView(date: entry.date, shown: entry.shown, snapshot: entry.snapshot)
                .privacySensitive()
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Month Calendar")
        .description("The whole month with each day's events.")
        .supportedFamilies([.systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct ItsycalWidgets: WidgetBundle {
    var body: some Widget {
        ItsycalWeekWidget()
        ItsycalMonthWidget()
    }
}
