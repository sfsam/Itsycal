import AppIntents
import WidgetKit

extension WidgetPeriod: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    static let caseDisplayRepresentations: [WidgetPeriod: DisplayRepresentation] = [.week: "Week", .month: "Month"]
}

/// Widget button action: show the next week/month, or return to the current one.
struct SwitchPeriodIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Period"
    static let isDiscoverable = false

    @Parameter(title: "Period", default: .week) var period: WidgetPeriod
    @Parameter(title: "Show Next", default: false) var next: Bool

    init() {}
    init(_ period: WidgetPeriod, next: Bool) {
        self.period = period
        self.next = next
    }

    func perform() async throws -> some IntentResult {
        PeriodNavigation.store(next ? .next(period, from: .now, calendar: WeekDates.calendar) : nil, for: period)
        // WidgetKit reloads the tapped widget; other instances share the state.
        WidgetCenter.shared.reloadTimelines(ofKind: period.kind)
        return .result()
    }
}
