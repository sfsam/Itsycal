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
@class EventInfo;

@interface EventCenter : NSObject

// Did the user grant calendar access?
@property (nonatomic, readonly) BOOL calendarAccessGranted;

// Has the user granted, denied or not yet been asked for
// reminders access? Itsycal only asks when the user clicks
// Show Reminders in Prefs, never at launch.
@property (nonatomic, readonly) EKAuthorizationStatus remindersAuthorizationStatus;

@property (nonatomic, readonly) NSString *defaultCalendarIdentifier;

// Delegate is responsible for...
@property (nonatomic, weak) id<EventCenterDelegate> delegate;

- (instancetype)initWithCalendar:(NSCalendar *)calendar delegate:(id<EventCenterDelegate>)delegate;

- (EKEvent *)newEvent;

// Save a new event and register its undo (remove it) and
// redo (save it again) with undoManager. Undo and redo do
// nothing but beep if the event has changed since, e.g. in
// Calendar or on another device.
- (BOOL)saveNewEvent:(EKEvent *)event undoManager:(NSUndoManager *)undoManager error:(NSError **)error;

- (BOOL)removeEvent:(EKEvent *)event span:(EKSpan)span error:(NSError **)error;

// Check off or uncheck a reminder and register its undo and redo
// with undoManager, as Calendar does. Checking off a repeating
// reminder makes EventKit save a completed copy at its due date and
// move the reminder to its next due date. Undoing that removes the
// copy and moves the reminder back. Undo and redo do nothing but
// beep if the reminder has changed since.
- (BOOL)setReminder:(EKReminder *)reminder completed:(BOOL)completed undoManager:(NSUndoManager *)undoManager error:(NSError **)error;

// Ask for reminders access. If it is granted, refetch so reminder
// lists are in -sourcesAndCalendars, then call completion on the
// main thread.
- (void)requestRemindersAccessWithCompletion:(void (^)(void))completion;

- (void)fetchEvents;

// Sorted array of 2 types: NSStrings and CalendarInfo objects.
// The NSStrings are the names of calendar sources.
// The CalendarInfo objects describe the calendars in those sources.
// Alphabetical by source, then calendar title. Each source is
// followed by its calendars. Reminder lists come after all the
// calendars, sorted the same way, under source names like
// "iCloud Reminders". Datasource for Prefs tableview.
- (NSArray *)sourcesAndCalendars;

// A dict that maps dates to an array of EventInfo objects.
// Only contains events for user's selected (i.e. filtered) calendars.
- (NSDictionary *)filteredEventsForDate;

// Reminders from selected lists whose current occurrence is due before
// date, for the agenda's Overdue section: incomplete ones, and ones
// checked off a moment ago, which linger briefly. Most recently due
// first. Their EventInfos have isInOverdueSection set.
- (NSArray<EventInfo *> *)remindersDueBeforeDate:(NSDate *)date;

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

// An EventInfo describes either an event or a reminder on a date.
// If both event and reminder are nil, there are no events on that
// date (the agenda shows an empty row).
@interface EventInfo : NSObject

@property (nonatomic) EKEvent *event;   // nil if there's no event on this date
// The day this is listed under in the agenda (its key in
// -filteredEventsForDate). An event that spans several days has an
// EventInfo for each, so this can be after the event's start date.
@property (nonatomic) NSDate *date;
@property (nonatomic) EKReminder *reminder; // nil if this isn't a reminder
@property (nonatomic) NSDate *dueDate;  // reminder's due date; start of day if it has no time
// A later occurrence of a repeating reminder, which is due on its
// current occurrence. Its dueDate is this occurrence's date. Calendar
// shows these dimmed, and they can't be checked off.
@property (nonatomic) BOOL isFutureOccurrence;
// Listed in the agenda's Overdue section, not under a day, so the
// agenda shows its due date.
@property (nonatomic) BOOL isInOverdueSection;
// event or reminder, for the properties they share
// (title, calendar, location, notes, URL, recurrence rules).
@property (nonatomic, readonly) EKCalendarItem *item;
// The event's start and end dates, or the reminder's due date.
@property (nonatomic, readonly) NSDate *startDate;
@property (nonatomic, readonly) NSDate *endDate;
// The event is an all-day event, or the reminder is due without a
// time. Unlike isAllDay, NO for a timed event spanning this date.
@property (nonatomic, readonly) BOOL isRealAllDay;
@property (nonatomic) BOOL isStartDate; // event starts, but doesn't end, on this date
@property (nonatomic) BOOL isEndDate;   // event ends, but doesn't start, on this date
@property (nonatomic) BOOL isAllDay;    // event is all-day, or spans across this date,
                                        // or reminder is due without a time
// Zoom, Google Meet, Microsoft Teams, etc. URL found in the event's
// location, URL or notes, or nil. Set by EventCenter on its background
// queue before the EventInfo is published, and never changed after that.
@property (nonatomic, readonly) NSURL *meetingURL;
@end

// meetingURL converted to an app link (zoommtg://, msteams://, chime://)
// if the meeting's app is installed; otherwise meetingURL unchanged.
NSURL *AppLinkForMeetingURL(NSURL *meetingURL);

// Is reminder due at dueDate (which may be nil, for no due date)?
// dueDate is as in EventInfo: the start of the day if no time.
BOOL ReminderIsDue(EKReminder *reminder, NSDate *dueDate);
