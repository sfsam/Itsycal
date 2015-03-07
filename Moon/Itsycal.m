//
//  Itsycal.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/3/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "Itsycal.h"

// Bundle IDs
NSString * const kItsycalBundleID = @"com.mowglii.ItsycalApp";
NSString * const kItsycalExtraBundleID = @"com.mowglii.ItsycalExtra";

// NSUserDefaults keys
NSString * const kPinItsycal = @"PinItsycal";
NSString * const kShowEventDays = @"ShowEventDays";
NSString * const kShowWeeks = @"ShowWeeks";
NSString * const kWeekStartDOW = @"WeekStartDOW";
NSString * const kKeyboardShortcut = @"KeyboardShortcut";

// Preferences notifications
NSString * const kDaysToShowPreferenceChanged = @"DaysToShowPreferenceChanged";

// Menu extra notifications
NSString * const ItsycalIsActiveNotification = @"ItsycalIsActiveNotification";
NSString * const ItsycalDidUpdateIconNotification = @"ItsycalDidUpdateIconNotification";
NSString * const ItsycalKeyboardShortcutNotification = @"ItsycalKeyboardShortcutNotification";
NSString * const ItsycalExtraIsActiveNotification = @"ItsycalMenuExtraIsActiveNotification";
NSString * const ItsycalExtraClickedNotification = @"ItsycalMenuExtraClickedNotification";
NSString * const ItsycalExtraDidMoveNotification = @"ItsycalMenuExtraDidMoveNotification";
NSString * const ItsycalExtraWillUnloadNotification = @"ItsycalMenuExtraWillUnloadNotification";

NSImage *ItsycalDateIcon(int day, NSImage *datesImage)
{
    day = (day < 0 || day > 31) ? 0 : day;
    CGFloat width = 19, height = 14;
    NSImage *image = [NSImage imageWithSize:NSMakeSize(width, height) flipped:NO drawingHandler:^BOOL (NSRect dstRect) {
        [datesImage drawInRect:NSMakeRect(0, 0, width, height) fromRect:NSMakeRect(day * width, 0, width, height) operation:NSCompositeSourceOver fraction:1];
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}
