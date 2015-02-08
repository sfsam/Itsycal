//
//  Itsycal.h
//  Itsycal2
//
//  Created by Sanjay Madan on 2/3/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoDate.h"

// NSUserDefaults keys
extern NSString * const kPinItsycal;
extern NSString * const kShowWeeks;
extern NSString * const kWeekStartDOW;
extern NSString * const kKeyboardShortcut;

NSImage *ItsycalDateIcon(int day, NSImage *datesImage);

