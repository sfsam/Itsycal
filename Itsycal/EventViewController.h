//
//  EventViewController.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/25/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EventCenter;

@interface EventViewController : NSViewController <NSTextFieldDelegate, NSTextViewDelegate>

@property (nonatomic, weak) EventCenter *ec;
@property (nonatomic, weak) NSPopover *enclosingPopover;
@property (nonatomic, weak) NSCalendar *cal;
@property (nonatomic) NSDate *calSelectedDate;
// The Itsycal window's undo manager. Saving registers undo here
// so ⌘Z works after the popover closes.
@property (nonatomic, weak) NSUndoManager *eventUndoManager;

@end
