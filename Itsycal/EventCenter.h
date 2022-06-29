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

// Did the user grant calendar access?
@property (nonatomic, readonly) BOOL calendarAccessGranted;

@property (nonatomic, readonly) NSString *defaultCalendarIdentifier;

// Delegate is responsible for...
@property (nonatomic, weak) id<EventCenterDelegate> delegate;

- (instancetype)initWithCalendar:(NSCalendar *)calendar delegate:(id<EventCenterDelegate>)delegate;

- (EKEvent *)newEvent;

- (BOOL)saveEvent:(EKEvent *)event error:(NSError **)error;

- (BOOL)removeEvent:(EKEvent *)event span:(EKSpan)span error:(NSError **)error;

- (void)fetchEvents;

// Sorted array of 2 types: NSStrings and CalendarInfo objects.
// The NSStrings are the names of calendar sources.
// The CalendarInfo objects describe the calendars in those sources.
// Alphabetical by source, then calendar title. Each source is
// followed by its calendars. Datasource for Prefs tableview.
- (NSArray *)sourcesAndCalendars;

// A dict that maps dates to an array of EventInfo objects.
// Only contains events for user's selected (i.e. filtered) calendars.
- (NSDictionary *)filteredEventsForDate;

// When the user selects/unselects calendars in Prefs, we update
// the list of selected calendars.
- (void)updateSelectedCalendarsForIdentifier:(NSString *)identifier selected:(BOOL)selected;

// Clear cached events and refetch.
- (void)refetchAll;

// Refresh event store.
- (void)refresh;

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
@property (nonatomic) NSURL *zoomURL;   // Zoom, Google Meet, Microsoft Teams, etc. URL
@end
