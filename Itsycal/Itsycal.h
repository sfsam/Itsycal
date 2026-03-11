//
//  Itsycal.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/3/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <objc/runtime.h>
#import <Cocoa/Cocoa.h>
#import "MoDate.h"

// NSUserDefaults keys
extern NSString * const kPinItsycal;
extern NSString * const kShowEventDays;
extern NSString * const kShowWeeks;
extern NSString * const kWeekStartDOW;
extern NSString * const kHighlightedDOWs;
extern NSString * const kKeyboardShortcut;
extern NSString * const kMenuBarIconType;
extern NSString * const kShowMonthInIcon;
extern NSString * const kShowDayOfWeekInIcon;
extern NSString * const kShowMeetingIndicator;
extern NSString * const kAllowOutsideApplicationsFolder;
extern NSString * const kClockFormat;
extern NSString * const kHideIcon;
extern NSString * const kShowLocation;
extern NSString * const kShowEventDots;
extern NSString * const kUseColoredDots;
extern NSString * const kBeepBeepOnTheHour;
extern NSString * const kBaselineOffset;
extern NSString * const kEnableMeetingButtonIndefinitely;
extern NSString * const kDoNotDrawOutlineAroundCurrentMonth;
extern NSString * const kShowDaysWithNoEventsInAgenda;
extern NSString * const kShowEventPopoverOnHover;
extern NSString * const kShowContactEvents;

// Set an associated object on NSDate to indicate
// whether of not this date has events.
// https://stackoverflow.com/a/16708352
@interface NSDate (HasNoEvents)
@end

@implementation NSDate (HasNoEvents)

- (BOOL)hasNoEvents {
    NSNumber *num = objc_getAssociatedObject(self, @selector(hasNoEvents));
    return [num boolValue];
}

- (void)setHasNoEvents:(BOOL)hasNoEvents {
    objc_setAssociatedObject(self, @selector(hasNoEvents), @(hasNoEvents), OBJC_ASSOCIATION_RETAIN);
}

@end
