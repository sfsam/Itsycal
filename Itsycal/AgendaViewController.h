//
//  AgendaViewController.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/18/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoTableView.h"

@protocol AgendaDelegate;

@interface AgendaViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, MoTableViewDelegate, NSMenuDelegate>

@property (nonatomic, weak) NSCalendar *nsCal;
@property (nonatomic) MoTableView *tv;
// Rows: NSDate (a day's heading), EventInfo (an event, a reminder or
// an empty day), and an AgendaOverdueHeading for the Overdue section
// at the top.
@property (nonatomic) NSArray *events;
@property (nonatomic, weak) id<AgendaDelegate> delegate;
@property (nonatomic) BOOL showLocation;

// Reload and scroll to the top.
- (void)reloadData;
// Reload without scrolling, for when only the data changed, so the
// user doesn't lose their place (e.g. checking off reminders in a
// long list).
- (void)reloadDataKeepingScrollPosition;
- (void)scrollToTop;
- (void)dimEventsIfNecessary;
- (BOOL)clickFirstActiveZoomButton;

@end

// The heading of the Overdue section: a disclosure chevron, "Overdue"
// and the number of overdue reminders. Clicking it shows or hides
// them (the rows after it).
@interface AgendaOverdueHeading : NSObject
@property (nonatomic) BOOL expanded;
@property (nonatomic) NSInteger count;
@end

@class EKEvent, EKReminder;

@protocol AgendaDelegate <NSObject>

@optional
- (void)agendaHoveredOverRow:(NSInteger)row;
- (void)agendaWantsToDeleteEvent:(EKEvent *)event;
- (void)agendaWantsToSetReminder:(EKReminder *)reminder completed:(BOOL)completed;
- (void)agendaWantsToToggleOverdueSection;
- (void)agendaShowCalendarAppAtDate:(NSDate *)date;
- (CGFloat)agendaMaxPossibleHeight;

@end
