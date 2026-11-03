#import <Foundation/Foundation.h>

@class EventCenter;

// Complete weeks covering this month and next month (so also this week and
// next week), aligned to the app's configured first day and independent of
// the menu-bar selection. weekStartDOW must be 0=Sunday ... 6=Saturday.
NSDateInterval *WeekSnapshotInterval(NSDate *date, NSInteger weekStartDOW);

// Write week.json, read by both widgets. Call on EventCenter's work queue.
void PublishWeekSnapshot(NSDictionary *eventsForDate, EventCenter *center,
                         NSDateInterval *interval, NSInteger weekStartDOW);
