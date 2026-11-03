#import "WeekSnapshot.h"
#import "EventCenter.h"
#import <AppKit/AppKit.h>
#import <os/log.h>
#import "Itsycal-Swift.h"

static NSDate *WeekStartContaining(NSDate *date, NSInteger weekStartDOW, NSCalendar *calendar)
{
    NSDate *day = [calendar startOfDayForDate:date];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:day] - 1;
    return [calendar dateByAddingUnit:NSCalendarUnitDay value:-((weekday - weekStartDOW + 7) % 7) toDate:day options:0];
}

NSDateInterval *WeekSnapshotInterval(NSDate *date, NSInteger weekStartDOW)
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = NSTimeZone.localTimeZone;
    NSDate *monthStart;
    [calendar rangeOfUnit:NSCalendarUnitMonth startDate:&monthStart interval:NULL forDate:date];
    NSDate *afterNext = [calendar dateByAddingUnit:NSCalendarUnitMonth value:2 toDate:monthStart options:0];
    NSDate *lastDay = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:afterNext options:0];
    NSDate *start = WeekStartContaining(monthStart, weekStartDOW, calendar);
    NSDate *end = [calendar dateByAddingUnit:NSCalendarUnitDay value:7
                                      toDate:WeekStartContaining(lastDay, weekStartDOW, calendar) options:0];
    return [[NSDateInterval alloc] initWithStartDate:start endDate:end];
}

void PublishWeekSnapshot(NSDictionary *eventsForDate, EventCenter *center,
                         NSDateInterval *interval, NSInteger weekStartDOW)
{
    NSString *group = [NSBundle.mainBundle objectForInfoDictionaryKey:@"ItsycalAppGroup"];
    NSURL *container = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group];
    if (!container) {
        os_log_error(OS_LOG_DEFAULT, "Widget shared container is unavailable");
        return;
    }

    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = NSTimeZone.localTimeZone;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.calendar = calendar;
    formatter.timeZone = calendar.timeZone;
    formatter.dateFormat = @"yyyy-MM-dd";

    NSString *status = !center.calendarAccessGranted ? @"permission"
                     : (!center.hasSelectedCalendars ? @"calendars" : @"ready");
    NSMutableDictionary *days = [NSMutableDictionary new];
    if ([status isEqualToString:@"ready"]) {
        for (NSDate *date = interval.startDate; [date compare:interval.endDate] == NSOrderedAscending;
             date = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:date options:0]) {
            NSMutableArray *items = [NSMutableArray new];
            for (EventInfo *info in eventsForDate[date]) {
                // Events and reminders share these EventInfo properties. The
                // widget has no checkboxes, so it leaves out completed reminders.
                if (info.reminder.isCompleted) continue;
                EKCalendarItem *item = info.item;
                NSColor *color = [[NSColor colorWithCGColor:item.calendar.CGColor] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
                [items addObject:@{
                    @"id": [NSString stringWithFormat:@"%@/%.0f", item.calendarItemIdentifier ?: @"", info.startDate.timeIntervalSince1970],
                    @"title": item.title.length ? item.title : NSLocalizedString(@"New Event", @""),
                    @"start": @(info.startDate.timeIntervalSince1970),
                    @"end": @(info.endDate.timeIntervalSince1970),
                    @"allDay": @(info.isRealAllDay),
                    @"spansDay": @(info.isAllDay),
                    @"startsHere": @([calendar isDate:date inSameDayAsDate:info.startDate]),
                    @"endsHere": @(info.isEndDate),
                    @"continues": @(info.isStartDate),
                    @"color": @[@(color ? color.redComponent : 0.3), @(color ? color.greenComponent : 0.5), @(color ? color.blueComponent : 0.8)]
                }];
            }
            days[[formatter stringFromDate:date]] = items;
        }
    }
    NSDictionary *content = @{
        @"timeZone": calendar.timeZone.name,
        @"start": @(interval.startDate.timeIntervalSince1970),
        @"end": @(interval.endDate.timeIntervalSince1970),
        @"status": status,
        @"weekStart": @(weekStartDOW),
        @"days": days
    };
    NSMutableDictionary *snapshot = [content mutableCopy];
    snapshot[@"version"] = @2;
    snapshot[@"generatedAt"] = @(NSDate.date.timeIntervalSince1970);
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:&error];
    if (!data || ![data writeToURL:[container URLByAppendingPathComponent:@"week.json"] options:NSDataWritingAtomic error:&error]) {
        os_log_error(OS_LOG_DEFAULT, "Unable to publish widget snapshot: %{public}@", error.localizedDescription);
        return;
    }
    // The file is always rewritten so generatedAt stays fresh for the widget's
    // hourly reload. Reloads are requested only when content changes, which
    // keeps frequent republishing within WidgetKit's reload budget.
    static NSDictionary *published; // Only touched on EventCenter's serial work queue.
    if ([content isEqualToDictionary:published]) return;
    published = content;
    [WidgetReloader reload];
}
