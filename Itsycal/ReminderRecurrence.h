//
//  Created by Sanjay Madan on 10/24/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>

// =========================================================================
// ReminderRecurrence
// Expand a repeating reminder's recurrence rule into dates.
// =========================================================================

// EventKit expands repeating events, but not repeating reminders: a
// repeating reminder is a single item due on its current occurrence.
// Calendar shows its later occurrences too, so Itsycal expands the rule
// itself, as RFC 5545 does, which matches Calendar.
//
// Returns the occurrences after start (the reminder's current due date,
// which is the first occurrence) that fall in [rangeStart, rangeEnd).
// calendar is a Gregorian calendar in the reminder's time zone, so an
// occurrence keeps start's time of day across daylight saving changes.
// A count in the rule's end counts start: EventKit lowers it each time
// the reminder is checked off. An end date is compared with each
// occurrence's date and time. Returns nil if the rule uses something
// this doesn't expand (weeks or days of the year).
NSArray<NSDate *> *RecurrenceDates(EKRecurrenceRule *rule, NSDate *start, NSCalendar *calendar, NSDate *rangeStart, NSDate *rangeEnd);
