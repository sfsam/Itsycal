import AppIntents
import SwiftUI

/// Everything a week or month widget derives from the snapshot, computed once per entry.
struct PeriodState {
    let period: WidgetPeriod
    let now: Date              // Drives today, past dimming and staleness.
    let shown: Date            // Any date inside the displayed period.
    let dates: [Date]          // Days drawn: 7 for a week, whole weeks for a month.
    let dayEvents: [[WeekEvent]] // Parallel to dates.
    let isNext: Bool
    let canShowNext: Bool
    let issue: String?
    let stale: Bool
    let total: Int             // Events on the period's own days.

    init(_ period: WidgetPeriod, now: Date, shown: Date, snapshot: WeekSnapshot?, calendar: Calendar) {
        let weekStart = snapshot?.weekStart ?? 1
        self.period = period
        self.now = now
        self.shown = shown
        dates = period.days(containing: shown, weekStart: weekStart, calendar: calendar)
        dayEvents = dates.map { snapshot?.days[WeekDates.key($0, calendar: calendar)] ?? [] }
        isNext = !period.isSame(shown, as: now, weekStart: weekStart, calendar: calendar)
        canShowNext = PeriodNavigation.canShowNext(period, snapshot: snapshot, today: now, calendar: calendar)
        if let snapshot {
            issue = snapshot.message(for: period, containing: shown, calendar: calendar)
            stale = now.timeIntervalSince1970 - snapshot.generatedAt > 86400
        } else {
            issue = String(localized: "Open Itsycal to set up events")
            stale = false
        }
        total = zip(dates, dayEvents)
            .filter { period == .week || calendar.isDate($0.0, equalTo: shown, toGranularity: .month) }
            .reduce(0) { $0 + $1.1.count }
    }
}

/// Title, range, ‹ › switch buttons and event count.
struct PeriodHeader: View {
    let state: PeriodState
    let compact: Bool
    let calendar: Calendar

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Link(destination: WeekDates.link(titleTarget, calendar: calendar)) {
                HStack(alignment: .firstTextBaseline, spacing: compact ? 4 : 6) {
                    Text(title).font(.system(size: compact ? 11 : 12, weight: .semibold))
                    Text(subtitle).font(.system(size: compact ? 9 : 10)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 2) {
                switchButton("chevron.left", next: false, enabled: state.isNext,
                             label: state.period == .week ? String(localized: "Back to this week") : String(localized: "Back to this month"))
                switchButton("chevron.right", next: true, enabled: !state.isNext && state.canShowNext,
                             label: state.period == .week ? String(localized: "Show next week") : String(localized: "Show next month"))
            }
            Spacer(minLength: 4)
            if state.issue == nil {
                Text("\(state.total) events")
                    .font(.system(size: compact ? 9 : 10)).foregroundStyle(.secondary)
            }
        }
        .frame(height: compact ? 16 : 18)
        .padding(.horizontal, 3)
    }

    private var title: String {
        switch state.period {
        case .week: state.isNext ? String(localized: "Next Week") : String(localized: "This Week")
        case .month: state.isNext ? String(localized: "Next Month") : String(localized: "This Month")
        }
    }

    private var subtitle: String {
        switch state.period {
        case .week:
            let formatter = DateIntervalFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateTemplate = compact ? "MMMd" : "yMMMd"
            return formatter.string(from: state.dates[0], to: state.dates[6])
        case .month:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: state.shown)
        }
    }

    /// Today for the current period, otherwise the first day of the next one.
    private var titleTarget: Date {
        guard state.isNext else { return state.now }
        return state.period == .week ? state.dates[0] : calendar.dateInterval(of: .month, for: state.shown)!.start
    }

    @ViewBuilder
    private func switchButton(_ symbol: String, next: Bool, enabled: Bool, label: String) -> some View {
        let icon = Image(systemName: symbol)
            .font(.system(size: compact ? 8 : 9, weight: .bold))
            .frame(width: compact ? 16 : 18, height: compact ? 14 : 16)
            .background(Color.primary.opacity(enabled ? 0.07 : 0.03), in: RoundedRectangle(cornerRadius: 4))
        if enabled {
            Button(intent: SwitchPeriodIntent(state.period, next: next)) { icon.foregroundStyle(.secondary) }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
        } else {
            icon.foregroundStyle(.quaternary).accessibilityHidden(true)
        }
    }
}

extension View {
    /// Issue message over the content, or a stale-data refresh icon in the corner.
    func periodOverlays(_ state: PeriodState, calendar: Calendar) -> some View {
        overlay {
            if let issue = state.issue {
                Link(destination: WeekDates.link(state.now, calendar: calendar)) {
                    Text(issue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12).padding(.top, 30)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if state.stale && state.issue == nil {
                Link(destination: WeekDates.link(state.now, calendar: calendar)) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Events may be out of date. Open Itsycal to update"))
            }
        }
    }
}

extension Color {
    static let itsycalAccent = Color(red: 0.19, green: 0.39, blue: 0.84)
}

extension WeekEvent {
    var tint: Color {
        Color(red: color.count > 0 ? color[0] : 0.3,
              green: color.count > 1 ? color[1] : 0.5,
              blue: color.count > 2 ? color[2] : 0.8)
    }
}
