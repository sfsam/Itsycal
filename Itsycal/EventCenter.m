//
//  EventCenter.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <os/log.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSAlert.h>
#import <AppKit/NSGraphics.h>
#import "EventCenter.h"

// NSUserDefaults key for array of selected calendar IDs.
static NSString *kSelectedCalendars = @"SelectedCalendars";

// meetingURL is readonly in the header; only EventCenter sets it.
@interface EventInfo ()
@property (nonatomic, readwrite) NSURL *meetingURL;
@property (nonatomic) BOOL didCheckMeetingURL; // _queueWork only
@end

// Properties auto-synthesized.
@implementation CalendarInfo @end
@implementation EventInfo
- (EKCalendarItem *)item { return _event ?: _reminder; }
- (NSDate *)startDate { return _reminder ? _dueDate : _event.startDate; }
- (NSDate *)endDate { return _reminder ? _dueDate : _event.endDate; }
- (BOOL)isRealAllDay { return _reminder ? _isAllDay : _event.isAllDay; }
@end

static NSURL *MeetingURLForEvent(EKEvent *event); // see below
static NSDate *DueDateForReminder(EKReminder *reminder, BOOL *hasTime); // see below
typedef EKEvent *(^EventMaker)(EKEventStore *store);
static EventMaker EventMakerForEvent(EKEvent *event); // see below

@implementation EventCenter {                      // Accessed on:
    EKEventStore         *_store;
    NSCalendar           *_cal;
    NSMutableDictionary  *_eventsForDate;          // _queueWork
    NSDictionary         *_filteredEventsForDate;  // _queueIsol
    NSMutableIndexSet    *_previouslyFetchedDates; // _queueWork
    NSArray<EKReminder *> *_completedReminders;    // _queueWork; nil until fetched
    NSArray              *_sourcesAndCalendars;    // _queueIsol2
    dispatch_queue_t      _queueWork;
    dispatch_queue_t      _queueIsol;
    dispatch_queue_t      _queueIsol2;
}

- (instancetype)initWithCalendar:(NSCalendar *)calendar delegate:(id<EventCenterDelegate>)delegate {
    
    EKEventStoreRequestAccessCompletionHandler requestCompletionHandler = ^(BOOL granted, NSError *error) {
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_store reset];
                [self refetchAll];
            });
        }
        else {
            // Fail silently. The alternative is to kick out to the
            // delegate so it can display an informative alert. But
            // that would happen every time the user launches Itsycal
            // (including when the system launches it at startup) and
            // seeing the same modal alert would get old fast.
        }
    };
    
    self = [super init];
    if (self) {
        _cal = calendar;
        _delegate = delegate;
        _sourcesAndCalendars = [NSArray new];
        _eventsForDate  = [NSMutableDictionary new];
        _filteredEventsForDate = [NSDictionary new];
        _previouslyFetchedDates = [NSMutableIndexSet new];
        _queueWork = dispatch_queue_create("com.mowglii.Itsycal.queueWork", DISPATCH_QUEUE_SERIAL);
        _queueIsol = dispatch_queue_create("com.mowglii.Itsycal.queueIsol", DISPATCH_QUEUE_SERIAL);
        _queueIsol2 = dispatch_queue_create("com.mowglii.Itsycal.queueIsol2", DISPATCH_QUEUE_SERIAL);
        _store = [EKEventStore new];
        [_store requestFullAccessToEventsWithCompletion:requestCompletionHandler];

        // Refetch everything when the event store has changed.
        __weak __typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:EKEventStoreChangedNotification object:_store queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            [weakSelf refetchAll];
        }];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public (main thread)

- (BOOL)calendarAccessGranted {
    return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusFullAccess;
}

- (EKAuthorizationStatus)remindersAuthorizationStatus {
    return [EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder];
}

- (void)requestRemindersAccessWithCompletion:(void (^)(void))completion {
    [_store requestFullAccessToRemindersWithCompletion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                // Reset on _queueWork, which fetches with the store,
                // so it can't happen in the middle of a fetch.
                dispatch_async(self->_queueWork, ^{
                    [self->_store reset];
                });
                [self refetchAll];
            }
            // -refetchAll does its work on _queueWork, which is serial,
            // so this runs after the reminder lists have been fetched.
            dispatch_async(self->_queueWork, ^{
                dispatch_async(dispatch_get_main_queue(), completion);
            });
        });
    }];
}

- (NSString *)defaultCalendarIdentifier {
    EKCalendar *cal = [_store defaultCalendarForNewEvents];
    return cal.calendarIdentifier;
}

- (EKEvent *)newEvent {
    return [EKEvent eventWithEventStore:_store];
}

- (BOOL)saveNewEvent:(EKEvent *)event undoManager:(NSUndoManager *)undoManager error:(NSError **)error {
    if (![_store saveEvent:event span:EKSpanThisEvent commit:YES error:error]) {
        return NO;
    }
    // Redo saves a fresh copy, since an event that has been
    // removed can't be saved again.
    [self _registerUndoForNewEvent:event maker:EventMakerForEvent(event) undoManager:undoManager];
    return YES;
}

- (BOOL)removeEvent:(EKEvent *)event span:(EKSpan)span error:(NSError **)error {
    return [_store removeEvent:event span:span commit:YES error:error];
}

- (void)updateSelectedCalendarsForIdentifier:(NSString *)identifier selected:(BOOL)selected {
    //os_log(OS_LOG_DEFAULT, "%s", __FUNCTION__);
    // The user has selected/unselected a calendar in Prefs.
    // Update the kSelectedCalendars array in NSUserDefaults.
    __block NSMutableArray *selectedCalendars = [NSMutableArray new];
    __block BOOL isReminderList = NO;
    dispatch_sync(_queueIsol2, ^{
        for (id obj in self->_sourcesAndCalendars) {
            if ([obj isKindOfClass:[CalendarInfo class]]) {
                CalendarInfo *info = obj;
                if ([info.calendar.calendarIdentifier isEqualToString:identifier]) {
                    info.selected = selected;
                    isReminderList = (info.calendar.allowedEntityTypes & EKEntityMaskReminder) != 0;
                }
                if (info.selected) {
                    [selectedCalendars addObject:info.calendar.calendarIdentifier];
                }
            }
        }
    });
    [[NSUserDefaults standardUserDefaults] setObject:selectedCalendars forKey:kSelectedCalendars];
    
    // Reminders are only fetched from selected lists (see
    // -_fetchRemindersWithStartDate:endDate:), so refetch.
    if (isReminderList) {
        [self refetchAll];
        return;
    }

    // Filter events based on new calendar selection.
    dispatch_async(_queueWork, ^{
        [self _filterEvents];
    });
}

- (NSArray *)sourcesAndCalendars {
    //os_log(OS_LOG_DEFAULT, "%s", __FUNCTION__);
    __block NSArray *sourcesAndCalendars;
    dispatch_sync(_queueIsol2, ^{
        sourcesAndCalendars = [self->_sourcesAndCalendars copy];
    });
    return sourcesAndCalendars;
}

- (NSDictionary *)filteredEventsForDate {
    //os_log(OS_LOG_DEFAULT, "%s", __FUNCTION__);
    __block NSDictionary *filteredEventsForDate;
    dispatch_sync(_queueIsol, ^{
        filteredEventsForDate = [self->_filteredEventsForDate copy];
    });
    return filteredEventsForDate;
}

- (void)fetchEvents {
    //os_log(OS_LOG_DEFAULT, "%s", __FUNCTION__);
    MoDate startMoDate = [self.delegate fetchStartDate];
    MoDate endMoDate   = [self.delegate fetchEndDate];
    dispatch_async(_queueWork, ^{
        @autoreleasepool {
            [self _fetchEventsWithStartDate:startMoDate endDate:endMoDate refetch:NO];
        }
    });
}

- (void)refetchAll {
    //os_log(OS_LOG_DEFAULT, "%s", __FUNCTION__);
    // Either the system told us the event store has changed or
    // we were called by the main controller. Clear the cache
    // and refetch everything.
    MoDate startMoDate = [self.delegate fetchStartDate];
    MoDate endMoDate   = [self.delegate fetchEndDate];
    dispatch_async(_queueWork, ^{
        @autoreleasepool {
            [self _fetchSourcesAndCalendars];
            [self _fetchEventsWithStartDate:startMoDate endDate:endMoDate refetch:YES];
        }
    });
}

- (void)refresh {
    dispatch_async(_queueWork, ^{
        [self->_store reset];
        [self->_store refreshSourcesIfNecessary];
    });
}

#pragma mark - Undo (main thread)

- (void)_registerUndoForNewEvent:(EKEvent *)event maker:(EventMaker)maker undoManager:(NSUndoManager *)undoManager {
    NSString *identifier = event.eventIdentifier;
    NSArray *fingerprint = [self _undoFingerprintForEvent:event];
    __weak NSUndoManager *weakUndoManager = undoManager;
    [undoManager registerUndoWithTarget:self handler:^(EventCenter *ec) {
        // Undo: remove the event, unless it is gone or has
        // changed since we saved it.
        EKEvent *saved = [ec->_store eventWithIdentifier:identifier];
        if (saved == nil || ![[ec _undoFingerprintForEvent:saved] isEqual:fingerprint]) {
            NSBeep();
            return;
        }
        // For a repeating event, saved is the first occurrence,
        // so EKSpanFutureEvents removes the whole series.
        NSError *error = nil;
        EKSpan span = saved.hasRecurrenceRules ? EKSpanFutureEvents : EKSpanThisEvent;
        if (![ec->_store removeEvent:saved span:span commit:YES error:&error]) {
            if (error != nil) [[NSAlert alertWithError:error] runModal];
            return;
        }
        // Redo: save a fresh copy, then register undo for it.
        [weakUndoManager registerUndoWithTarget:ec handler:^(EventCenter *ec) {
            EKEvent *copy = maker(ec->_store);
            NSError *error = nil;
            if (![ec->_store saveEvent:copy span:EKSpanThisEvent commit:YES error:&error]) {
                if (error != nil) [[NSAlert alertWithError:error] runModal];
                return;
            }
            [ec _registerUndoForNewEvent:copy maker:maker undoManager:weakUndoManager];
        }];
    }];
}

// The fields of an event that undo checks to tell whether it changed
// after Itsycal saved it. The store may normalize saved dates, so
// times are compared to the minute (the date pickers' precision),
// and all-day events by start day only.
- (NSArray *)_undoFingerprintForEvent:(EKEvent *)event {
    id start, end;
    if (event.isAllDay) {
        start = [_cal startOfDayForDate:event.startDate];
        end   = NSNull.null;
    }
    else {
        start = @(floor(event.startDate.timeIntervalSinceReferenceDate / 60));
        end   = @(floor(event.endDate.timeIntervalSinceReferenceDate / 60));
    }
    return @[event.title ?: @"",
             event.calendar.calendarIdentifier ?: @"",
             @(event.isAllDay), start, end];
}

#pragma mark - Private (GCD thread pool)

- (void)_fetchSourcesAndCalendars {
    //os_log(OS_LOG_DEFAULT, " %s", __FUNCTION__);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSSet *selectedCalendars = [NSSet setWithArray:[defaults arrayForKey:kSelectedCalendars]];

    // Make an array of source titles and calendar info. Calendars
    // first, then reminder lists if the user has granted access.
    NSMutableArray *sourcesAndCalendars = [NSMutableArray new];
    [self _addCalendarsForEntityType:EKEntityTypeEvent toSourcesAndCalendars:sourcesAndCalendars selectedCalendars:selectedCalendars];
    if (self.remindersAuthorizationStatus == EKAuthorizationStatusFullAccess) {
        [self _addCalendarsForEntityType:EKEntityTypeReminder toSourcesAndCalendars:sourcesAndCalendars selectedCalendars:selectedCalendars];
    }
    dispatch_async(_queueIsol2, ^{
        self->_sourcesAndCalendars = [NSArray arrayWithArray:sourcesAndCalendars];
    });
}

- (void)_addCalendarsForEntityType:(EKEntityType)entityType toSourcesAndCalendars:(NSMutableArray *)sourcesAndCalendars selectedCalendars:(NSSet *)selectedCalendars {
    // Get an array of the user's calendars (or reminder lists)
    // sorted first by source title and then by calendar title.
    NSArray *calendars = [[_store calendarsForEntityType:entityType] sortedArrayUsingComparator:^NSComparisonResult(EKCalendar *cal1, EKCalendar *cal2) {
        if ([cal1.source.sourceIdentifier isEqualToString:cal2.source.sourceIdentifier]) {
            return [cal1.title compare:cal2.title];
        }
        else {
            return [cal1.source.title compare:cal2.source.title];
        }
    }];
    
    // Some calendars (e.g. some CalDAV and Exchange ones) hold both
    // events and reminders. List each calendar once: its checkbox
    // shows both, since fetches go by entity type.
    NSMutableSet *listed = [NSMutableSet new];
    for (id obj in sourcesAndCalendars) {
        if ([obj isKindOfClass:[CalendarInfo class]]) {
            [listed addObject:((CalendarInfo *)obj).calendar.calendarIdentifier];
        }
    }
    
    NSString *currentSourceTitle = @"";
    for (EKCalendar *calendar in calendars) {
        if ([listed containsObject:calendar.calendarIdentifier]) continue;
        NSString *calendarSourceTitle = calendar.source.title;
        // (!) Should never hit this case, but MacOS 13 sometimes returns
        // nil for non-iCloud source titles. Use a dummy title instead.
        if (!calendar.source.title) calendarSourceTitle = @"???";
        if (entityType == EKEntityTypeReminder) {
            calendarSourceTitle = [NSString stringWithFormat:NSLocalizedString(@"%@ Reminders", @"Heading for a source's reminder lists in Settings, e.g. iCloud Reminders"), calendarSourceTitle];
        }
        if (!calendar.color) {
            // Skip calendars where the color is nil.
            // This normally doesn't happen, but there are some
            // edge cases where it does.
            // See: github.com/sfsam/Itsycal/issues/152
            continue;
        }
        if (![calendarSourceTitle isEqualToString:currentSourceTitle]) {
            [sourcesAndCalendars addObject:calendarSourceTitle];
            currentSourceTitle = calendarSourceTitle;
        }
        CalendarInfo *calInfo = [CalendarInfo new];
        calInfo.calendar = calendar;
        calInfo.selected = selectedCalendars ? [selectedCalendars containsObject:calendar.calendarIdentifier] : NO;
        [sourcesAndCalendars addObject:calInfo];
    }
}

- (NSArray *)_validCalendarsForEntityMask:(EKEntityMask)entityMask
{
    // Valid calendars are calendars (or reminder lists) in
    // _sourcesAndCalendars. They have been filtered to remove
    // calendars where the color is nil.
    // See -_fetchSourcesAndCalendars
    __block NSMutableArray *calendars = [NSMutableArray new];
    dispatch_sync(_queueIsol2, ^{
        for (id obj in self->_sourcesAndCalendars) {
            if ([obj isKindOfClass:[CalendarInfo class]]) {
                CalendarInfo *calInfo = obj;
                if (calInfo.calendar.allowedEntityTypes & entityMask) {
                    [calendars addObject:calInfo.calendar];
                }
            }
        }
    });
    return calendars;
}

- (void)_fetchEventsWithStartDate:(MoDate)startMoDate endDate:(MoDate)endMoDate refetch:(BOOL)refetch
{
    //os_log(OS_LOG_DEFAULT, " %s", __FUNCTION__);
    if (refetch) {
        _previouslyFetchedDates = [NSMutableIndexSet new];
        _eventsForDate = [NSMutableDictionary new];
        _completedReminders = nil;
    }
    // Return immediately if we've already fetched for this date range.
    NSRange dateRange = NSMakeRange(startMoDate.julian, endMoDate.julian - startMoDate.julian);
    if ([_previouslyFetchedDates containsIndexesInRange:dateRange])  {
        //os_log(OS_LOG_DEFAULT, "SKIPPING: %@ - %@", NSStringFromMoDate(startMoDate), NSStringFromMoDate(endMoDate));
        return;
    }
    
    // Reduce the range [startMoDate, endMoDate] based on dates previously fetched.
    NSMutableIndexSet *notYetFetchedDates = [NSMutableIndexSet new];
    for (NSInteger julian = startMoDate.julian; julian <= endMoDate.julian; julian++) {
        if (![_previouslyFetchedDates containsIndex:julian]) {
            [notYetFetchedDates addIndex:julian];
        }
    }
    if (notYetFetchedDates.count > 0) {
        startMoDate = MakeGregorian(notYetFetchedDates.firstIndex);
        endMoDate   = MakeGregorian(notYetFetchedDates.lastIndex);
    }
    
    // Update _previouslyFetchedDates for this fetch.
    [_previouslyFetchedDates addIndexesInRange:dateRange];
    
    NSDate *startDate = MakeNSDateWithDate(startMoDate, _cal);
    NSDate *endDate   = MakeNSDateWithDate(endMoDate,   _cal);
    NSArray *cals = [self _validCalendarsForEntityMask:EKEntityMaskEvent];
    NSPredicate *predicate = [_store predicateForEventsWithStartDate:startDate endDate:endDate calendars:cals];
    NSArray *events = [_store eventsMatchingPredicate:predicate];
    NSMutableDictionary *eventsForDate = [NSMutableDictionary new];
    
    // Does EKEvent still respond to the private 'participationStatus'
    // selector? Check once instead of risking an NSUndefinedKeyException
    // on every event if a future OS renames or removes it.
    static BOOL participationStatusKeySupported;
    static dispatch_once_t participationStatusOnceToken;
    dispatch_once(&participationStatusOnceToken, ^{
        participationStatusKeySupported = [EKEvent instancesRespondToSelector:NSSelectorFromString(@"participationStatus")];
    });

    // Iterate over events matching startDate/endDate. We will
    // populate a dictionary, eventsForDate, that maps each date
    // to an array of events that fall on that date.
    for (EKEvent *event in events) {
        
        // Skip events the current user has declined.
        // Use 'valueForKey' to get private 'participationStatus' property.
        // This is much faster than accessing the 'attendees' property
        // and then looping over the participants to see if the current
        // user has declined the event.
        if (event.hasAttendees && participationStatusKeySupported &&
            [[event valueForKey:@"participationStatus"] integerValue] == EKParticipantStatusDeclined) {
            continue;
        }
        
        // Iterate through the days this event spans. We only care about
        // days for this event that are between startDate and endDate.
        NSDate *date  = [event.startDate laterDate:startDate];
        NSDate *final = [event.endDate earlierDate:endDate];
        date  = [_cal startOfDayForDate:date];
        while ([date compare:final] == NSOrderedAscending) {
            
            NSDate *nextDate = [_cal dateByAddingUnit:NSCalendarUnitDay value:1 toDate:date options:0];
            nextDate = [_cal startOfDayForDate:nextDate];
            
            // Make an EventInfo object...
            EventInfo *info = [EventInfo new];
            info.event       = event;
            //   isStartDate = (it starts on `date` AND ends not before `nextDate`)
            info.isStartDate = ([_cal isDate:date inSameDayAsDate:event.startDate] &&
                                [event.endDate compare:nextDate] != NSOrderedAscending);
            //   isEndDate   = (it ends on `date` AND starts before `date`)
            info.isEndDate   = ([_cal isDate:date inSameDayAsDate:event.endDate] &&
                                [event.startDate compare:date] == NSOrderedAscending);
            //   isAllDay    = (it's a real all-day event OR
            //                  (it starts before `date` AND ends not before `nextDate`))
            info.isAllDay    = (event.allDay ||
                                ([event.startDate compare:date] == NSOrderedAscending &&
                                 [event.endDate compare:nextDate] != NSOrderedAscending));
            // ...and add it to the array in eventsForDate.
            if (eventsForDate[date] == nil) {
                eventsForDate[date] = [NSMutableArray new];
            }
            [eventsForDate[date] addObject:info];
            
            date = nextDate;
        }
    }
    
    // Add reminders that are due between startDate and endDate.
    for (EKReminder *reminder in [self _fetchRemindersWithStartDate:startDate endDate:endDate]) {
        BOOL hasTime;
        NSDate *dueDate = DueDateForReminder(reminder, &hasTime);
        if (dueDate == nil) continue;
        NSDate *date = [_cal startOfDayForDate:dueDate];
        if ([date compare:startDate] == NSOrderedAscending ||
            [date compare:endDate] != NSOrderedAscending) {
            continue;
        }
        EventInfo *info = [EventInfo new];
        info.reminder = reminder;
        info.dueDate  = hasTime ? dueDate : date;
        // A reminder without a time goes with the all-day events,
        // as in Calendar.
        info.isAllDay = !hasTime;
        if (eventsForDate[date] == nil) {
            eventsForDate[date] = [NSMutableArray new];
        }
        [eventsForDate[date] addObject:info];
    }

    // eventsForDate is a dict that maps dates to an array of EventInfo objects.
    // Sort those arrays so that AllDay events are first, the sort by startTime.
    // All-day events are sorted by calendar title with real all-day events before
    // spanning all-day events. Reminders without a time sort like real all-day
    // events, and reminders with a time sort by their due date.
    for (NSDate *date in eventsForDate) {
        [eventsForDate[date] sortUsingComparator:^NSComparisonResult(EventInfo *e1, EventInfo *e2) {
            if (e1.isRealAllDay && e2.isRealAllDay)  { return [e1.item.calendar.title compare:e2.item.calendar.title];}
            else if (e1.isRealAllDay && !e2.isRealAllDay) { return NSOrderedAscending; }
            else if (!e1.isRealAllDay && e2.isRealAllDay) { return NSOrderedDescending; }
            else if (e1.isAllDay && e2.isAllDay) { return [e1.item.calendar.title compare:e2.item.calendar.title];}
            else if (e1.isAllDay) { return NSOrderedAscending;  }
            else if (e2.isAllDay) { return NSOrderedDescending; }
            else { return [e1.startDate compare:e2.startDate]; }
        }];
    }
    
    [_eventsForDate addEntriesFromDictionary:eventsForDate];
    [self _filterEvents];
}

- (NSArray<EKReminder *> *)_fetchRemindersWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    // A calendar that holds events and reminders allows reminders
    // even when the user hasn't granted reminders access.
    if (self.remindersAuthorizationStatus != EKAuthorizationStatusFullAccess) return @[];

    // Unlike events, fetch only from selected lists, since we fetch
    // every completed reminder (see below). Selecting or unselecting
    // a list refetches. See -updateSelectedCalendarsForIdentifier:selected:.
    NSSet *selectedCalendars = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:kSelectedCalendars]];
    NSMutableArray *lists = [NSMutableArray new];
    for (EKCalendar *list in [self _validCalendarsForEntityMask:EKEntityMaskReminder]) {
        if ([selectedCalendars containsObject:list.calendarIdentifier]) {
            [lists addObject:list];
        }
    }
    if (lists.count == 0) return @[];

    // Incomplete reminders due in the range, and completed reminders.
    // EventKit can only fetch completed reminders by completion date,
    // not due date, so fetch them all, once per refetch, and reuse
    // them for the other dates the user moves to. The caller filters
    // by due date.
    NSMutableArray<EKReminder *> *reminders = [NSMutableArray arrayWithArray:[self _fetchRemindersMatchingPredicate:[_store predicateForIncompleteRemindersWithDueDateStarting:startDate ending:endDate calendars:lists]]];
    if (_completedReminders == nil) {
        _completedReminders = [self _fetchRemindersMatchingPredicate:[_store predicateForCompletedRemindersWithCompletionDateStarting:nil ending:nil calendars:lists]];
    }
    [reminders addObjectsFromArray:_completedReminders];
    // Only reminders with a due date belong on the calendar.
    return [reminders filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"dueDateComponents != nil"]];
}

- (NSArray<EKReminder *> *)_fetchRemindersMatchingPredicate:(NSPredicate *)predicate
{
    // We're on _queueWork, which can wait. EventKit calls
    // completion on a queue of its own.
    __block NSArray<EKReminder *> *reminders = @[];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [_store fetchRemindersMatchingPredicate:predicate completion:^(NSArray<EKReminder *> *fetched) {
        if (fetched) reminders = fetched;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return reminders;
}

- (void)_filterEvents {
    //os_log(OS_LOG_DEFAULT, " %s", __FUNCTION__);
    NSMutableDictionary *filteredEventsForDate = [NSMutableDictionary new];
    NSArray *selectedCalendars = [[NSUserDefaults standardUserDefaults] arrayForKey:kSelectedCalendars];
    for (NSDate *date in _eventsForDate) {
        for (EventInfo *info in _eventsForDate[date]) {
            if ([selectedCalendars containsObject:info.item.calendar.calendarIdentifier]) {
                if (filteredEventsForDate[date] == nil) {
                    filteredEventsForDate[date] = [NSMutableArray new];
                }
                // Check if there is a virtual meeting (e.g. Zoom) link.
                // We limit this check to filtered events in an
                // attempt to limit how much text processing we do.
                // Check each EventInfo only once, before it is first
                // published below. After that the main thread may be
                // reading it, so it must not be written again. Store
                // changes trigger a refetch, which creates new EventInfos.
                if (!info.didCheckMeetingURL && info.event) {
                    info.meetingURL = MeetingURLForEvent(info.event);
                    info.didCheckMeetingURL = YES;
                }
                [filteredEventsForDate[date] addObject:info];
            }
        }
    }
    // Notify the delegate from inside the _queueIsol block so the
    // write to _filteredEventsForDate is visible before the delegate
    // reads it back via -filteredEventsForDate.
    dispatch_async(_queueIsol, ^{
        self->_filteredEventsForDate = [filteredEventsForDate copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate eventCenterEventsChanged];
        });
    });
}

@end

// =========================================================================
// Reminders
// =========================================================================

// Return the date a reminder is due. A reminder may be due on a
// day without a time. Then *hasTime is NO, and the date is the
// start of that day in the local time zone, like an all-day event.
static NSDate *DueDateForReminder(EKReminder *reminder, BOOL *hasTime)
{
    *hasTime = NO;
    if (reminder.dueDateComponents == nil) return nil;
    NSDateComponents *components = [reminder.dueDateComponents copy];
    *hasTime = components.hour != NSDateComponentUndefined;
    // The components carry their own calendar (usually Gregorian),
    // which may differ from the user's. A time is in the components'
    // time zone, if any. A day without a time is in the local one.
    NSCalendar *calendar = [components.calendar ?: [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] copy];
    calendar.timeZone = (*hasTime && components.timeZone) ? components.timeZone : [NSTimeZone localTimeZone];
    components.calendar = nil;
    components.timeZone = nil;
    return [calendar dateFromComponents:components];
}

// =========================================================================
// Undo
// =========================================================================

// Return a block that makes a new, unsaved copy of event, with the
// fields Itsycal's new-event popover sets (see -[EventViewController
// saveEvent:]). The block captures plain values, not EventKit
// objects, because -[EKEventStore reset] discards unsaved objects.
static EventMaker EventMakerForEvent(EKEvent *event)
{
    NSString *title      = event.title;
    NSString *location   = event.location;
    NSURL *URL           = event.URL;
    BOOL allDay          = event.isAllDay;
    NSDate *startDate    = event.startDate;
    NSDate *endDate      = event.endDate;
    NSString *calendarID = event.calendar.calendarIdentifier;
    NSString *notes      = event.notes;
    NSTimeZone *timeZone = event.timeZone;
    EKRecurrenceRule *rule = event.recurrenceRules.firstObject;
    BOOL hasRule = rule != nil;
    EKRecurrenceFrequency frequency = rule.frequency;
    NSInteger interval   = rule.interval;
    NSDate *ruleEndDate  = rule.recurrenceEnd.endDate;
    NSMutableArray<NSNumber *> *alarmOffsets = [NSMutableArray new];
    for (EKAlarm *alarm in event.alarms) {
        [alarmOffsets addObject:@(alarm.relativeOffset)];
    }
    return ^EKEvent *(EKEventStore *store) {
        EKEvent *copy  = [EKEvent eventWithEventStore:store];
        copy.title     = title;
        copy.location  = location;
        copy.URL       = URL;
        copy.allDay    = allDay;
        copy.startDate = startDate;
        copy.endDate   = endDate;
        copy.calendar  = [store calendarWithIdentifier:calendarID];
        copy.notes     = notes;
        // timeZone MUST be nil for an all-day event, and set after allDay.
        copy.timeZone  = timeZone;
        if (hasRule) {
            EKRecurrenceEnd *end = ruleEndDate ? [EKRecurrenceEnd recurrenceEndWithEndDate:ruleEndDate] : nil;
            copy.recurrenceRules = @[[[EKRecurrenceRule alloc] initRecurrenceWithFrequency:frequency interval:interval end:end]];
        }
        // Replace any default alarms with the event's own.
        for (EKAlarm *alarm in copy.alarms) {
            [copy removeAlarm:alarm];
        }
        for (NSNumber *offset in alarmOffsets) {
            [copy addAlarm:[EKAlarm alarmWithRelativeOffset:offset.doubleValue]];
        }
        return copy;
    };
}

// =========================================================================
// Meeting links
// =========================================================================

static BOOL HostIs(NSString *host, NSString *domain)
{
    return [host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]];
}

// Return the first virtual meeting (e.g. Zoom) link in text, or nil.
static NSURL *MeetingURLInText(NSString *text)
{
    static NSDataDetector *linkDetector = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
    });
    __block NSURL *meetingURL = nil;
    [linkDetector enumerateMatchesInString:text options:kNilOptions range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        NSURL *url = result.URL;
        // Match on the URL's host (and scheme, for app-link URIs), not on
        // the raw URL string. A substring check like
        // [link containsString:@"zoom.us/j/"] would also match a hostile
        // link such as https://evil.example/zoom.us/j/123.
        NSString *host   = url.host.lowercaseString ?: @"";
        NSString *path   = url.path ?: @"";
        NSString *scheme = url.scheme.lowercaseString ?: @"";
        BOOL (^hostIs)(NSString *) = ^BOOL(NSString *domain) {
            return HostIs(host, domain);
        };
        BOOL (^hostHasPrefix)(NSString *) = ^BOOL(NSString *prefix) {
            return [host hasPrefix:prefix];
        };
        if (   (   (hostIs(@"zoom.us") || hostIs(@"zoomgov.com"))
                && ([path hasPrefix:@"/j/"] || [path hasPrefix:@"/s/"]
                    || [path hasPrefix:@"/w/"] || [path hasPrefix:@"/my/"]))
            || (hostIs(@"teams.microsoft.com") && [path hasPrefix:@"/l/meetup-join/"])
            || hostIs(@"chime.aws")
            || [scheme isEqualToString:@"zoommtg"]
            || [scheme isEqualToString:@"msteams"]
            || [scheme isEqualToString:@"chime"]
            || hostIs(@"meet.google.com")
            || hostIs(@"hangouts.google.com")
            || hostIs(@"webex.com")
            || (hostIs(@"gotomeeting.com") && [path hasPrefix:@"/join"])
            || (hostIs(@"ringcentral.com") && [path hasPrefix:@"/j"])
            || (hostIs(@"bigbluebutton.org") && [path hasPrefix:@"/gl"])
            || ([scheme isEqualToString:@"https"] && (hostHasPrefix(@"bigbluebutton.") || hostHasPrefix(@"bbb.")))
            || hostIs(@"meet.jit.si")
            || hostIs(@"indigo.collocall.de")
            || hostIs(@"public.senfcall.de")
            || (hostIs(@"facetime.apple.com") && [path hasPrefix:@"/join"])
            || (hostIs(@"workplace.com") && [path hasPrefix:@"/meet"])
            || (hostIs(@"youcanbook.me") && [path hasPrefix:@"/zoom/"])
            || (hostIs(@"vk.com") && [path hasPrefix:@"/call/"])) {
            meetingURL = url;
            *stop = YES;
        }
    }];
    return meetingURL;
}

NSURL *AppLinkForMeetingURL(NSURL *meetingURL)
{
    NSString *link = meetingURL.absoluteString;
    NSString *host = meetingURL.host.lowercaseString ?: @"";
    NSString *path = meetingURL.path ?: @"";
    NSURL *appLink = nil;
    // Personal Zoom links (/my/) are left as is; the rewrite below
    // doesn't handle them and would produce a broken app link.
    if (   (HostIs(host, @"zoom.us") || HostIs(host, @"zoomgov.com"))
        && ([path hasPrefix:@"/j/"] || [path hasPrefix:@"/s/"] || [path hasPrefix:@"/w/"])) {
        // Test if user has the Zoom app and, if so, create a Zoom app link.
        if ([NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"zoommtg://"]]) {
            link = [link stringByReplacingOccurrencesOfString:@"https://" withString:@"zoommtg://"];
            link = [link stringByReplacingOccurrencesOfString:@"?" withString:@"&"];
            link = [link stringByReplacingOccurrencesOfString:@"/j/" withString:@"/join?confno="];
            link = [link stringByReplacingOccurrencesOfString:@"/s/" withString:@"/join?confno="];
            link = [link stringByReplacingOccurrencesOfString:@"/w/" withString:@"/join?confno="];
            appLink = [NSURL URLWithString:link];
        }
    }
    else if (HostIs(host, @"teams.microsoft.com") && [path hasPrefix:@"/l/meetup-join/"]) {
        // Test if user has the Teams app and, if so, create a Teams app link.
        if ([NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"msteams://"]]) {
            link = [link stringByReplacingOccurrencesOfString:@"https://" withString:@"msteams://"];
            appLink = [NSURL URLWithString:link];
        }
    }
    else if (HostIs(host, @"chime.aws")) {
        // Test if user has the Chime app, and if so, create a Chime app link.
        if ([NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"chime://"]]) {
            link = [link stringByReplacingOccurrencesOfString:@"https://chime.aws/" withString:@"chime://meeting?pin="];
            appLink = [NSURL URLWithString:link];
        }
    }
    return appLink ?: meetingURL;
}

static NSURL *MeetingURLForEvent(EKEvent *event)
{
    NSURL *meetingURL = nil;
    if (event.location) meetingURL = MeetingURLInText(event.location);
    if (!meetingURL && event.URL) meetingURL = MeetingURLInText(event.URL.absoluteString);
    if (!meetingURL && event.hasNotes && event.notes) meetingURL = MeetingURLInText(event.notes);
    return meetingURL;
}
