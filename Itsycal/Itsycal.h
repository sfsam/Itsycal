//
//  Itsycal.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/3/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoDate.h"

// Bundle IDs
extern NSString * const kItsycalBundleID;
extern NSString * const kItsycalExtraBundleID;

// NSUserDefaults keys
extern NSString * const kPinItsycal;
extern NSString * const kShowEventDays;
extern NSString * const kShowWeeks;
extern NSString * const kWeekStartDOW;
extern NSString * const kKeyboardShortcut;
extern NSString * const kHighlightWeekend;
extern NSString * const kShowIcon;
extern NSString * const kShowData;
extern NSString * const kShowDayOfWeek;
extern NSString * const kShowTime;
extern NSString * const kAllowOutsideApplicationsFolder;

// Menu extra notifications
extern NSString * const ItsycalIsActiveNotification;
extern NSString * const ItsycalDidUpdateIconNotification;
extern NSString * const ItsycalKeyboardShortcutNotification;
extern NSString * const ItsycalExtraIsActiveNotification;
extern NSString * const ItsycalExtraClickedNotification;
extern NSString * const ItsycalExtraDidMoveNotification;
extern NSString * const ItsycalExtraWillUnloadNotification;

NSImage *ItsycalIconImageForText(NSString *text);
BOOL OSVersionIsAtLeast(NSInteger majorVersion, NSInteger minorVersion, NSInteger patchVersion);
