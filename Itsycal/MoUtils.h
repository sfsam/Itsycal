//
//  MoUtils.h
//
//
//  Created by Sanjay Madan on 10/31/16.
//  Copyright © 2016 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>

/**
 * A clock that increments monotonically, tracking the time since an arbitrary
 * point, and will continue to increment while the system is asleep.
 * Use this instead of CACurrentMediaTime() to measure durations that might be
 * interrupted by the system going to sleep. CACurrentMediaTime() is also a
 * monotonic timer, but it stops counting when the CPU sleeps.
 */
NSTimeInterval MonotonicClockTime(void);

/**
 * If the locale is English and we are in 12 hour time, remove :00 from a
 * formatted duration string. Effect is 3:00 PM -> 3 PM.
 */
NSString *StringByStrippingZeroMinutes(NSString *duration);

/**
 * The locale to use for NSDateIntervalFormatter. Usually the current locale.
 * On macOS 27, NSDateIntervalFormatter returns empty strings for some
 * settings, e.g. language English (US), region Croatia and List sort order
 * Croatian. In that case, return an equivalent locale without the sort
 * order. Call on the main thread.
 * Workaround for a macOS 27 bug; can be removed once Apple fixes it.
 */
NSLocale *DateIntervalFormatterLocale(void);

/**
 * The date range from start to end, with medium dates and short times,
 * e.g. "Oct 15, 2026, 10 AM – 12 PM". No times if allDay. Just one date
 * (and time) if start and end are the same, as for a reminder.
 * Call on the main thread.
 */
NSString *DateRangeString(NSDate *start, NSDate *end, BOOL allDay);

/**
 * The date at which a virtual meeting becomes joinable: 15 minutes prior
 * to an event's start.
 */
NSDate *MeetingJoinableThreshold(EKEvent *event, NSCalendar *calendar);
