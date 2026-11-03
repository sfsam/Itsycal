//
//  ViewController.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoCalendar.h"
#import "EventCenter.h"
#import "AgendaViewController.h"

@interface ViewController : NSViewController <NSWindowDelegate, AgendaDelegate, MoCalendarDelegate, EventCenterDelegate, NSPopoverDelegate, NSMenuDelegate>

- (void)keyboardShortcutActivated;
- (void)removeStatusItem;
- (void)dateURLReceived:(NSDate *)showDate;
- (void)widgetDateReceived:(NSDate *)showDate;

@end
