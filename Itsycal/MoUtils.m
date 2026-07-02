//
//  MoUtils.m
//  
//
//  Created by Sanjay Madan on 10/31/16.
//  Copyright © 2016 mowglii.com. All rights reserved.
//

#import <time.h>
#import "MoUtils.h"

NSTimeInterval MonotonicClockTime(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1.e-9;
}

NSString *StringByStrippingZeroMinutes(NSString *duration)
{
    if ([[[NSLocale currentLocale] localeIdentifier] hasPrefix:@"en"]) {
        if ([duration containsString:@"AM"] || [duration containsString:@"PM"] ||
            [duration containsString:@"am"] || [duration containsString:@"pm"]) {
            duration = [duration stringByReplacingOccurrencesOfString:@":00" withString:@""];
        }
    }
    return duration;
}

NSDate *AdjustedEventEndDate(EKEvent *event, NSCalendar *calendar)
{
    if (@available(macOS 13.0, *)) {
        return event.endDate;
    }
    return event.isAllDay
        ? [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:event.endDate options:0]
        : event.endDate;
}

NSDate *MeetingJoinableThreshold(EKEvent *event, NSCalendar *calendar)
{
    return [calendar dateByAddingUnit:NSCalendarUnitSecond value:-(15 * 60 + 30) toDate:event.startDate options:0];
}
