//
//  EventCenter.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>

// =========================================================================
// EventCenter
// Provide calendar and event data. Currently implemented using EventKit,
// but the interface and data it provides is only Foundation types. So, it
// could be reimplemented in the future using native CalDAV without changes
// to the clients.
// =========================================================================

@protocol EventCenterDelegate;

@interface EventCenter : NSObject

// Did the user grant calnedar access?
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

// When the user selects/unselects calendars in Prefs, we update
// the list of selected calendars.
- (void)updateSelectedCalendars;

@end

// =========================================================================
// EventCenterDelegate
// =========================================================================

@protocol EventCenterDelegate <NSObject>

- (void)eventCenterSourcesAndCalendarsChanged;

@end

// =========================================================================
// CalendarInfo
// =========================================================================

@interface CalendarInfo : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSColor  *color;
@property (nonatomic) BOOL selected;

@end

