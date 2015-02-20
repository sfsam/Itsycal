//
//  EventCenter.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MoDate.h"

// =========================================================================
// EventCenter
// Provide calendar and event data. Currently implemented using EventKit,
// but the interface and data it provides is only Foundation types. So, it
// could be reimplemented in the future using native CalDAV without changes
// to the clients.
// =========================================================================

@protocol EventCenterDelegate;

@interface EventCenter : NSObject

// Did the user grant calendar access?
@property (nonatomic) BOOL calendarAccessGranted;

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
- (NSArray *)eventsForDate:(MoDate)date;

// When the user selects/unselects calendars in Prefs, we update
// the list of selected calendars.
- (void)updateSelectedCalendars;

@end

// =========================================================================
// EventCenterDelegate
// =========================================================================

@protocol EventCenterDelegate <NSObject>

- (void)eventCenterSourcesAndCalendarsChanged;
- (void)eventCenterEventsChanged;
- (MoDate)fetchStartDate;
- (MoDate)fetchEndDate;

@end

// =========================================================================
// CalendarInfo
// =========================================================================

@interface CalendarInfo : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *identifier;
@property (nonatomic) NSColor  *color;
@property (nonatomic) BOOL      selected;

@end

// =========================================================================
// EventInfo
// =========================================================================

@interface EventInfo : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *calendarIdentifier;
@property (nonatomic) NSColor  *calendarColor;
@property (nonatomic) NSDate   *startDate;
@property (nonatomic) NSDate   *endDate;
@property (nonatomic) BOOL      isStartDate; // event starts, but doesn't end, on this date
@property (nonatomic) BOOL      isEndDate;   // event ends, but doesn't start, on this date
@property (nonatomic) BOOL      isAllDay;

@end

