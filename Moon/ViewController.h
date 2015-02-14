//
//  ViewController.h
//  Itsycal2
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EventCenter.h"

/*
 
 ViewController has these responsibilities:
 - manage the MoCalendar view
 - manage the Add, Calendar, Options buttons
 - manage the agenda view controller
 
 */

@interface ViewController : NSViewController <NSWindowDelegate, EventCenterDelegate>

- (void)keyboardShortcutActivated;

@end
