//
//  EventCenter.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import "MoDate.h"

// =========================================================================
// EventCenter
// Provide calendar and event data.
// =========================================================================

@protocol EventCenterDelegate;

@interface EventCenter : NSObject

// The event store
@property (nonatomic) EKEventStore *store;

// Did the user grant calendar access?
@property (nonatomic, readonly) BOOL calendarAccessGranted;

@property (nonatomic, readonly) NSString *defaultCalendarIdentifier;

// Sorted array of 2 types: NSStrings and CalendarInfo objects.
// The NSStrings are the names of calendar sources.
// The CalendarInfo objects describe the calendars in those sources.
// Alphabetical by source, then calendar title. Each source is
// followed by its calendars. Datasource for Prefs tableview.
@property (nonatomic, readonly) NSArray *sourcesAndCalendars;

// Delegate is responsible for...
@property (nonatomic, weak) id<EventCenterDelegate> delegate;

- (instancetype)initWithCalendar:(NSCalendar *)calendar delegate:(id<EventCenterDelegate>)delegate;

- (void)fetchEvents;

// An array of EventInfo objects for date. The array is
// sorted with all-day events first, then by startTime.
// Datasource for calendar tooltips.
- (NSArray *)eventsForDate:(MoDate)date;

// An array of NSDate and EventInfo objects for events
// starting at date and continuing for duration.
// Datasource for agenda.
- (NSArray *)datesAndEventsForDate:(MoDate)date days:(NSInteger)days;

// When the user selects/unselects calendars in Prefs, we update
// the list of selected calendars.
- (void)updateSelectedCalendars;

// Clear cached events and refetch.
- (void)refetchAll;

@end

// =========================================================================
// EventCenterDelegate
// =========================================================================

@protocol EventCenterDelegate <NSObject>

- (void)eventCenterEventsChanged;
- (MoDate)fetchStartDate;
- (MoDate)fetchEndDate;

@end

// =========================================================================
// CalendarInfo
// =========================================================================

@interface CalendarInfo : NSObject

@property (nonatomic) EKCalendar *calendar;
@property (nonatomic) BOOL selected;

@end

// =========================================================================
// EventInfo
// =========================================================================

@interface EventInfo : NSObject

@property (nonatomic) EKEvent *event;
@property (nonatomic) BOOL isStartDate; // event starts, but doesn't end, on this date
@property (nonatomic) BOOL isEndDate;   // event ends, but doesn't start, on this date
@property (nonatomic) BOOL isAllDay;    // event is all-day, or spans across this date

@end

