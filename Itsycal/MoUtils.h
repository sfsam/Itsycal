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
 * An all-day event's endDate meaning changed in macOS 13: before, it was
 * midnight of the day AFTER the last day of the event (exclusive). Since
 * macOS 13, it's 11:59:59 PM of the last day itself (inclusive). This
 * returns the correct end date to display/use for either convention.
 */
NSDate *AdjustedEventEndDate(EKEvent *event, NSCalendar *calendar);

/**
 * The date at which a virtual meeting becomes joinable: 15 minutes prior
 * to an event's start.
 */
NSDate *MeetingJoinableThreshold(EKEvent *event, NSCalendar *calendar);
