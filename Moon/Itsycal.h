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

// Preferences notifications
extern NSString * const kDaysToShowPreferenceChanged;

// Menu extra notifications
extern NSString * const ItsycalIsActiveNotification;
extern NSString * const ItsycalDidUpdateIconNotification;
extern NSString * const ItsycalKeyboardShortcutNotification;
extern NSString * const ItsycalExtraIsActiveNotification;
extern NSString * const ItsycalExtraClickedNotification;
extern NSString * const ItsycalExtraDidMoveNotification;
extern NSString * const ItsycalExtraWillUnloadNotification;

NSImage *ItsycalDateIcon(NSInteger day, NSImage *datesImage);
BOOL OSVersionIsAtLeast(NSInteger majorVersion, NSInteger minorVersion, NSInteger patchVersion);
