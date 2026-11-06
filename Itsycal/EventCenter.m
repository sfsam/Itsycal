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
#import "Itsycal.h"
#import "ReminderRecurrence.h"

// NSUserDefaults key for array of selected calendar IDs.
static NSString *kSelectedCalendars = @"SelectedCalendars";

// When completed reminders are hidden, a reminder stays this many
// seconds after it's checked off, so the user sees it happen.
static const NSTimeInterval kCompletedReminderLinger = 1;

// meetingURL is readonly in the header; only EventCenter sets it.
@interface EventInfo ()
@property (nonatomic, readwrite) NSURL *meetingURL;
@property (nonatomic) BOOL didCheckMeetingURL; // _queueWork only
@end

// Properties auto-synthesized.
@implementation CalendarInfo @end
@implementation EventInfo
- (EKCalendarItem *)item { return _event ?: _reminder; }
- (NSString *)location
{
    NSString *location = [self.item.location stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return location.length > 0 ? location : nil;
}
- (NSDate *)startDate { return _reminder ? _dueDate : _event.startDate; }
- (NSDate *)endDate { return _reminder ? _dueDate : _event.endDate; }
- (BOOL)isRealAllDay { return _reminder ? _isAllDay : _event.isAllDay; }
@end

static NSURL *MeetingURLForEvent(EKEvent *event); // see below
static NSDate *DueDateForReminder(EKReminder *reminder, BOOL *hasTime, NSCalendar **calendar); // see below
static NSArray<NSDictionary *> *AlarmValuesOfReminder(EKReminder *reminder); // see below
static NSComparisonResult CompareItemsOnDay(EventInfo *e1, EventInfo *e2); // see below

// The parts of a reminder that checking it off can change, kept as
// plain values (not EventKit objects, which -[EKEventStore reset]
// can invalidate) so undo can put them back.
@interface ReminderState : NSObject
@property (nonatomic) NSDateComponents *dueDateComponents;
@property (nonatomic) NSDateComponents *startDateComponents;
@property (nonatomic) NSDate *dueDate;
@property (nonatomic) NSDate *completionDate;
// See AlarmValuesOfReminder().
@property (nonatomic) NSArray<NSDictionary *> *alarmValues;
// The remaining count of a repeating reminder that ends after a number
// of times, or 0. EventKit lowers it when the reminder is checked off.
@property (nonatomic) NSUInteger occurrenceCount;
+ (instancetype)stateOfReminder:(EKReminder *)reminder;
// Put back what checking off a repeating reminder changes: its dates,
// alarms and remaining count.
- (void)restoreReminder:(EKReminder *)reminder;
@end
typedef EKEvent *(^EventMaker)(EKEventStore *store);
static EventMaker EventMakerForEvent(EKEvent *event); // see below

@implementation EventCenter {                      // Accessed on:
    EKEventStore         *_store;
    NSCalendar           *_cal;
    NSMutableDictionary  *_eventsForDate;          // _queueWork
    NSDictionary         *_filteredEventsForDate;  // _queueIsol
    NSMutableIndexSet    *_previouslyFetchedDates; // _queueWork
    NSMutableDictionary<NSString *, NSDate *> *_completedRemindersFirstSeen; // _queueWork
    NSArray<EKReminder *> *_incompleteReminders;   // _queueWork; nil until fetched
    NSArray<EKReminder *> *_completedReminders;    // _queueWork; nil until fetched
    NSArray<EventInfo *>  *_overdueCandidates;     // _queueWork
    NSSet<NSString *>     *_previousIncompleteIDs; // _queueWork
    NSArray<EventInfo *>  *_filteredOverdueCandidates; // _queueIsol
    NSUInteger            _lingerRefetchGeneration; // main thread
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
            // Reminders don't need calendar access, so fetch them
            // (and their lists) if the user granted reminders access.
            if ([EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder] == EKAuthorizationStatusFullAccess) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self refetchAll];
                });
            }
        }
    };
    
    self = [super init];
    if (self) {
        _cal = calendar;
        _delegate = delegate;
        _sourcesAndCalendars = [NSArray new];
        _eventsForDate  = [NSMutableDictionary new];
        _filteredEventsForDate = [NSDictionary new];
        _overdueCandidates = @[];
        _filteredOverdueCandidates = @[];
        _previouslyFetchedDates = [NSMutableIndexSet new];
        _completedRemindersFirstSeen = [NSMutableDictionary new];
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

- (NSArray<EventInfo *> *)remindersDueBeforeDate:(NSDate *)date {
    __block NSArray<EventInfo *> *candidates;
    dispatch_sync(_queueIsol, ^{
        candidates = self->_filteredOverdueCandidates;
    });
    // Already sorted. See -_filterEvents.
    NSMutableArray<EventInfo *> *reminders = [NSMutableArray new];
    for (EventInfo *info in candidates) {
        if ([info.dueDate compare:date] == NSOrderedAscending) [reminders addObject:info];
    }
    return reminders;
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

- (BOOL)setReminder:(EKReminder *)reminder completed:(BOOL)completed undoManager:(NSUndoManager *)undoManager error:(NSError **)error {
    return [self _setReminder:reminder completed:completed completionDate:nil undoManager:undoManager error:error];
}

// completionDate is the date to record when checking off, or nil
// for now. Undoing an uncheck uses it to restore the original date.
- (BOOL)_setReminder:(EKReminder *)reminder completed:(BOOL)completed completionDate:(NSDate *)completionDate undoManager:(NSUndoManager *)undoManager error:(NSError **)error {
    ReminderState *before = [ReminderState stateOfReminder:reminder];
    BOOL wasCompleted = reminder.isCompleted;
    NSDate *savedAt = [NSDate date];
    reminder.completed = completed;
    if (completed && completionDate) reminder.completionDate = completionDate;
    if (![_store saveReminder:reminder commit:YES error:error]) {
        reminder.completed = wasCompleted;
        if (wasCompleted) reminder.completionDate = before.completionDate;
        return NO;
    }
    // When EventKit checks off a repeating reminder that has a next
    // occurrence, it saves a completed copy and moves this reminder,
    // still incomplete, to its next due date. Go by what it did, not
    // by hasRecurrenceRules: the last occurrence of a series that
    // ends is just completed in place.
    BOOL advanced = completed && !reminder.isCompleted;
    if (advanced) {
        [self _registerUndoForAdvancedReminder:reminder before:before savedAt:savedAt undoManager:undoManager];
    }
    else {
        [self _registerUndoForReminder:reminder completed:completed before:before undoManager:undoManager];
    }
    return YES;
}

// Undo for checking off a reminder that doesn't repeat, or for
// unchecking one: set it back. That registers its own undo, which
// goes on the redo stack.
- (void)_registerUndoForReminder:(EKReminder *)reminder completed:(BOOL)completed before:(ReminderState *)before undoManager:(NSUndoManager *)undoManager {
    NSString *identifier = reminder.calendarItemIdentifier;
    __weak NSUndoManager *weakUndoManager = undoManager;
    [undoManager registerUndoWithTarget:self handler:^(EventCenter *ec) {
        EKReminder *current = [ec _reminderWithIdentifier:identifier];
        if (current == nil || current.isCompleted != completed || !ReminderIsDue(current, before.dueDate)) {
            NSBeep();
            return;
        }
        NSError *error = nil;
        if (![ec _setReminder:current completed:!completed completionDate:before.completionDate undoManager:weakUndoManager error:&error]) {
            if (error != nil) [[NSAlert alertWithError:error] runModal];
        }
    }];
}

// Undo for checking off a repeating reminder. EventKit saved a
// completed copy at the old due date and moved the reminder to its
// next due date. Undo removes the copy and moves the reminder back.
- (void)_registerUndoForAdvancedReminder:(EKReminder *)reminder before:(ReminderState *)before savedAt:(NSDate *)savedAt undoManager:(NSUndoManager *)undoManager {
    NSString *identifier = reminder.calendarItemIdentifier;
    NSString *title = reminder.title;
    NSString *calendarIdentifier = reminder.calendar.calendarIdentifier;
    BOOL hasTime;
    NSDate *nextDueDate = DueDateForReminder(reminder, &hasTime, NULL);
    __weak NSUndoManager *weakUndoManager = undoManager;

    // Find the copy now, so it's usually known by the time the user
    // undoes. If it isn't, undo looks for it then.
    __block NSString *copyIdentifier = nil;
    void (^findCopy)(void (^)(NSString *)) = ^(void (^completion)(NSString *)) {
        [self _findCompletedCopyOfReminder:identifier title:title calendar:calendarIdentifier dueDate:before.dueDate completedSince:[savedAt dateByAddingTimeInterval:-1] completion:completion];
    };
    findCopy(^(NSString *found) {
        copyIdentifier = found;
    });

    [undoManager registerUndoWithTarget:self handler:^(EventCenter *ec) {
        // Redo: check it off again. Register it now, while undoing, so
        // it goes on the redo stack even if the undo finishes later. If
        // the undo fails, the reminder is still advanced, so redo beeps.
        [weakUndoManager registerUndoWithTarget:ec handler:^(EventCenter *ec) {
            EKReminder *current = [ec _reminderWithIdentifier:identifier];
            if (current == nil || current.isCompleted || !ReminderIsDue(current, before.dueDate)) {
                NSBeep();
                return;
            }
            NSError *error = nil;
            if (![ec _setReminder:current completed:YES completionDate:nil undoManager:weakUndoManager error:&error]) {
                if (error != nil) [[NSAlert alertWithError:error] runModal];
            }
        }];
        if (copyIdentifier) {
            [ec _moveBackReminder:identifier from:nextDueDate removingCopy:copyIdentifier before:before];
        }
        else {
            findCopy(^(NSString *found) {
                copyIdentifier = found;
                [ec _moveBackReminder:identifier from:nextDueDate removingCopy:found before:before];
            });
        }
    }];
}

// Undo checking off a repeating reminder: remove its completed copy
// and move it back from nextDueDate to its old due date, together.
// Beep if either has changed since.
- (void)_moveBackReminder:(NSString *)identifier from:(NSDate *)nextDueDate removingCopy:(NSString *)copyIdentifier before:(ReminderState *)before {
    EKReminder *current = [self _reminderWithIdentifier:identifier];
    EKReminder *copy = copyIdentifier ? [self _reminderWithIdentifier:copyIdentifier] : nil;
    if (current == nil || current.isCompleted || !ReminderIsDue(current, nextDueDate) ||
        copy == nil || !copy.isCompleted || !ReminderIsDue(copy, before.dueDate)) {
        NSBeep();
        return;
    }
    NSError *error = nil;
    [before restoreReminder:current];
    if (![_store removeReminder:copy commit:NO error:&error] ||
        ![_store saveReminder:current commit:NO error:&error] ||
        ![_store commit:&error]) {
        // Discard the uncommitted changes now, so a later save can't
        // commit them. Reset on _queueWork, which fetches with the
        // store, and wait: _queueWork never waits on the main thread.
        dispatch_sync(_queueWork, ^{
            [self->_store reset];
        });
        [self refetchAll];
        if (error != nil) [[NSAlert alertWithError:error] runModal];
    }
}

// Find the completed copy EventKit saved when it checked off a
// repeating reminder: a completed reminder in the same list, with
// the same title and the old due date, completed since we saved.
// Call completion on the main thread with its identifier, or nil.
- (void)_findCompletedCopyOfReminder:(NSString *)identifier title:(NSString *)title calendar:(NSString *)calendarIdentifier dueDate:(NSDate *)dueDate completedSince:(NSDate *)completedSince completion:(void (^)(NSString *copyIdentifier))completion {
    EKCalendar *calendar = [_store calendarWithIdentifier:calendarIdentifier];
    if (calendar == nil) {
        completion(nil);
        return;
    }
    NSPredicate *predicate = [_store predicateForCompletedRemindersWithCompletionDateStarting:completedSince ending:nil calendars:@[calendar]];
    [_store fetchRemindersMatchingPredicate:predicate completion:^(NSArray<EKReminder *> *reminders) {
        NSString *found = nil;
        for (EKReminder *r in reminders) {
            if (![r.calendarItemIdentifier isEqualToString:identifier] && !r.hasRecurrenceRules
                && (r.title == title || [r.title isEqualToString:title])
                && ReminderIsDue(r, dueDate)) {
                found = r.calendarItemIdentifier;
                break;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(found);
        });
    }];
}

- (EKReminder *)_reminderWithIdentifier:(NSString *)identifier {
    EKCalendarItem *item = [_store calendarItemWithIdentifier:identifier];
    return [item isKindOfClass:[EKReminder class]] ? (EKReminder *)item : nil;
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
        _incompleteReminders = nil;
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
            info.date        = date;
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
    
    // Add reminders that are due between startDate and endDate, and
    // the later occurrences of repeating reminders that fall there.
    // Also collect each incomplete reminder's current occurrence (and
    // lingering completed ones) for the agenda's Overdue section. The
    // main thread picks those due before today when it builds the
    // agenda, so the section is right after midnight too.
    NSSet<NSString *> *lingeringIDs;
    NSArray<EKReminder *> *reminders = [self _fetchRemindersWithStartDate:startDate endDate:endDate lingering:&lingeringIDs];
    NSMutableArray<EventInfo *> *overdueCandidates = [NSMutableArray new];
    for (EKReminder *reminder in reminders) {
        // Only reminders with a due date belong on the calendar.
        BOOL hasTime;
        NSCalendar *dueCalendar;
        NSDate *dueDate = DueDateForReminder(reminder, &hasTime, &dueCalendar);
        if (dueDate == nil) continue;
        if (!reminder.isCompleted || [lingeringIDs containsObject:reminder.calendarItemIdentifier]) {
            NSDate *day = [_cal startOfDayForDate:dueDate];
            EventInfo *info = [EventInfo new];
            info.reminder = reminder;
            info.date     = day;
            info.dueDate  = hasTime ? dueDate : day;
            info.isAllDay = !hasTime;
            info.isInOverdueSection = YES;
            [overdueCandidates addObject:info];
        }
        NSMutableArray<NSDate *> *occurrences = [NSMutableArray arrayWithObject:dueDate];
        if (!reminder.isCompleted && reminder.hasRecurrenceRules) {
            NSArray *later = RecurrenceDates(reminder.recurrenceRules.firstObject, dueDate, dueCalendar, startDate, endDate);
            if (later) [occurrences addObjectsFromArray:later];
        }
        for (NSDate *occurrence in occurrences) {
            NSDate *date = [_cal startOfDayForDate:occurrence];
            if ([date compare:startDate] == NSOrderedAscending ||
                [date compare:endDate] != NSOrderedAscending) {
                continue;
            }
            EventInfo *info = [EventInfo new];
            info.reminder = reminder;
            info.date     = date;
            info.dueDate  = hasTime ? occurrence : date;
            info.isFutureOccurrence = occurrence != dueDate;
            // A reminder without a time goes with the all-day events,
            // as in Calendar.
            info.isAllDay = !hasTime;
            if (eventsForDate[date] == nil) {
                eventsForDate[date] = [NSMutableArray new];
            }
            [eventsForDate[date] addObject:info];
        }
    }
    _overdueCandidates = overdueCandidates;

    // eventsForDate is a dict that maps dates to an array of EventInfo objects.
    // Sort each day's items. See CompareItemsOnDay().
    for (NSDate *date in eventsForDate) {
        [eventsForDate[date] sortUsingComparator:^NSComparisonResult(EventInfo *e1, EventInfo *e2) {
            return CompareItemsOnDay(e1, e2);
        }];
    }
    
    [_eventsForDate addEntriesFromDictionary:eventsForDate];
    [self _filterEvents];
}

// The reminders to show: incomplete ones, and completed ones if the user
// shows them, or else just those still lingering after being checked
// off. *lingeringIDs is set to the identifiers of lingering ones.
- (NSArray<EKReminder *> *)_fetchRemindersWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate lingering:(NSSet<NSString *> **)lingeringIDs
{
    *lingeringIDs = [NSSet set];

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

    // Incomplete reminders and completed reminders. Fetch all the
    // incomplete ones, once per refetch, and reuse them for the other
    // dates the user moves to: ones due before the range are needed for
    // repeating reminders, whose later occurrences can fall in it.
    // EventKit can only fetch completed reminders by completion date,
    // not due date, so fetch them all, also once per refetch. The
    // caller filters by due date.
    // A just-completed reminder lingers for kCompletedReminderLinger
    // seconds (see -_completedReminderIsLingering:...), then goes: from
    // the day lists if the user hides completed reminders, and from the
    // Overdue section.
    // If the user hides completed reminders, fetch only those that may
    // linger: ones completed in the last few seconds (the store keeps
    // completion dates to the second, and the change takes a moment to
    // arrive, so look back further than kCompletedReminderLinger), and
    // ones that were incomplete in the previous fetch or are lingering,
    // whatever their completion date. (Undoing an uncheck restores the
    // original completion date.)
    BOOL showCompleted = [[NSUserDefaults standardUserDefaults] boolForKey:kShowCompletedReminders];
    NSDate *now = [NSDate date];
    if (_incompleteReminders == nil) {
        _incompleteReminders = [self _fetchRemindersMatchingPredicate:[_store predicateForIncompleteRemindersWithDueDateStarting:nil ending:nil calendars:lists]];
    }
    NSMutableSet<NSString *> *incompleteIDs = [NSMutableSet new];
    for (EKReminder *reminder in _incompleteReminders) {
        [incompleteIDs addObject:reminder.calendarItemIdentifier];
        // Unchecked (e.g. by undo), so it lingers
        // again if it's checked off again.
        [_completedRemindersFirstSeen removeObjectForKey:reminder.calendarItemIdentifier];
    }
    NSArray<EKReminder *> *completed;
    if (showCompleted) {
        if (_completedReminders == nil) {
            _completedReminders = [self _fetchRemindersMatchingPredicate:[_store predicateForCompletedRemindersWithCompletionDateStarting:nil ending:nil calendars:lists]];
        }
        completed = _completedReminders;
    }
    else {
        NSMutableDictionary<NSString *, EKReminder *> *byID = [NSMutableDictionary new];
        NSDate *completedSince = [now dateByAddingTimeInterval:-(kCompletedReminderLinger + 5)];
        for (EKReminder *reminder in [self _fetchRemindersMatchingPredicate:[_store predicateForCompletedRemindersWithCompletionDateStarting:completedSince ending:nil calendars:lists]]) {
            byID[reminder.calendarItemIdentifier] = reminder;
        }
        NSMutableSet<NSString *> *maybeLingering = [NSMutableSet setWithSet:_previousIncompleteIDs ?: [NSSet set]];
        [maybeLingering minusSet:incompleteIDs];
        for (NSString *identifier in _completedRemindersFirstSeen) {
            if ([now timeIntervalSinceDate:_completedRemindersFirstSeen[identifier]] < kCompletedReminderLinger) {
                [maybeLingering addObject:identifier];
            }
        }
        for (NSString *identifier in maybeLingering) {
            if (byID[identifier]) continue;
            EKCalendarItem *item = [_store calendarItemWithIdentifier:identifier];
            if ([item isKindOfClass:[EKReminder class]] && ((EKReminder *)item).isCompleted &&
                [selectedCalendars containsObject:item.calendar.calendarIdentifier]) {
                byID[identifier] = (EKReminder *)item;
            }
        }
        completed = byID.allValues;
    }

    NSDate *nextExpiry = nil;
    NSMutableSet<NSString *> *lingering = [NSMutableSet new];
    NSMutableArray<EKReminder *> *reminders = [NSMutableArray arrayWithArray:_incompleteReminders];
    for (EKReminder *reminder in completed) {
        BOOL isLingering = [self _completedReminderIsLingering:reminder now:now nextExpiry:&nextExpiry];
        if (isLingering) [lingering addObject:reminder.calendarItemIdentifier];
        if (showCompleted || isLingering) [reminders addObject:reminder];
    }
    _previousIncompleteIDs = incompleteIDs;
    *lingeringIDs = lingering;

    // Forget reminders that stopped lingering an hour ago. Keep them that
    // long so one isn't taken as newly completed again, e.g. because its
    // completion date is in the future (set by a device whose clock runs
    // fast).
    for (NSString *identifier in _completedRemindersFirstSeen.allKeys) {
        if ([now timeIntervalSinceDate:_completedRemindersFirstSeen[identifier]] > 60 * 60) {
            [_completedRemindersFirstSeen removeObjectForKey:identifier];
        }
    }
    [self _scheduleLingerEnd:nextExpiry];
    return reminders;
}

// Is a completed reminder lingering? It lingers for
// kCompletedReminderLinger seconds from when Itsycal first sees it
// completed, if that's right after it was checked off (here or
// elsewhere): Itsycal saw it incomplete in the previous fetch, or it
// was completed a moment ago (e.g. the completed copy EventKit saves
// when a repeating reminder is checked off, which was never
// incomplete). Records when it was first seen, and lowers *nextExpiry
// to when it stops lingering.
- (BOOL)_completedReminderIsLingering:(EKReminder *)reminder now:(NSDate *)now nextExpiry:(NSDate **)nextExpiry
{
    NSString *identifier = reminder.calendarItemIdentifier;
    NSDate *firstSeen = _completedRemindersFirstSeen[identifier];
    if (firstSeen == nil) {
        NSDate *completionDate = reminder.completionDate;
        BOOL wasIncomplete = [_previousIncompleteIDs containsObject:identifier];
        BOOL justCompleted = completionDate && fabs([completionDate timeIntervalSinceDate:now]) <= kCompletedReminderLinger + 5;
        if (!wasIncomplete && !justCompleted) return NO;
        firstSeen = now;
        _completedRemindersFirstSeen[identifier] = now;
    }
    NSDate *expiry = [firstSeen dateByAddingTimeInterval:kCompletedReminderLinger];
    if ([expiry compare:now] != NSOrderedDescending) return NO;
    if (*nextExpiry == nil || [expiry compare:*nextExpiry] == NSOrderedAscending) {
        *nextExpiry = expiry;
    }
    return YES;
}

// When the next lingering reminder should go, remove it: refetch if
// the user hides completed reminders, since the day lists change. If
// they're shown, only the Overdue section changes, so don't refetch
// (and refetch every completed reminder): just drop it from there.
// Keep only the latest scheduled time. Fetches can come in bursts (a
// save posts several store-change notifications), and the latest one
// knows the earliest expiry that's still pending.
- (void)_scheduleLingerEnd:(NSDate *)expiry
{
    if (expiry == nil) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger generation = ++self->_lingerRefetchGeneration;
        NSTimeInterval delay = MAX(expiry.timeIntervalSinceNow, 0) + 0.05;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self->_lingerRefetchGeneration) return;
            if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowCompletedReminders]) {
                dispatch_async(self->_queueWork, ^{
                    [self _dropExpiredOverdueCandidates];
                });
            }
            else {
                [self refetchAll];
            }
        });
    });
}

- (void)_dropExpiredOverdueCandidates
{
    NSDate *now = [NSDate date];
    NSDate *nextExpiry = nil;
    NSMutableArray<EventInfo *> *kept = [NSMutableArray new];
    for (EventInfo *info in _overdueCandidates) {
        if (info.reminder.isCompleted) {
            NSDate *firstSeen = _completedRemindersFirstSeen[info.reminder.calendarItemIdentifier];
            NSDate *expiry = [firstSeen dateByAddingTimeInterval:kCompletedReminderLinger];
            if (firstSeen == nil || [expiry compare:now] != NSOrderedDescending) continue;
            if (nextExpiry == nil || [expiry compare:nextExpiry] == NSOrderedAscending) nextExpiry = expiry;
        }
        [kept addObject:info];
    }
    _overdueCandidates = kept;
    [self _scheduleLingerEnd:nextExpiry];
    [self _filterEvents];
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
    // Overdue candidates, most recent day first, then in the same order
    // as a day's items.
    NSMutableArray *filteredOverdueCandidates = [NSMutableArray new];
    for (EventInfo *info in _overdueCandidates) {
        if ([selectedCalendars containsObject:info.item.calendar.calendarIdentifier]) {
            [filteredOverdueCandidates addObject:info];
        }
    }
    [filteredOverdueCandidates sortUsingComparator:^NSComparisonResult(EventInfo *e1, EventInfo *e2) {
        NSComparisonResult result = [e2.date compare:e1.date];
        return result != NSOrderedSame ? result : CompareItemsOnDay(e1, e2);
    }];
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
        self->_filteredOverdueCandidates = [filteredOverdueCandidates copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate eventCenterEventsChanged];
        });
    });
}

@end

// =========================================================================
// Sorting
// =========================================================================

// A completed reminder after an incomplete item.
static NSComparisonResult CompletedLast(EventInfo *e1, EventInfo *e2)
{
    BOOL c1 = e1.reminder.isCompleted, c2 = e2.reminder.isCompleted;
    if (c1 == c2) return NSOrderedSame;
    return c1 ? NSOrderedDescending : NSOrderedAscending;
}

// The order of items on the same day: all-day items first, then by
// start time. All-day events are sorted by calendar title with real
// all-day events before spanning all-day events. Reminders without a
// time sort like real all-day events, and reminders with a time sort
// by their due date.
// As in Calendar, a completed reminder goes after the incomplete items at
// the same time (or among the all-day items), but never after a later item.
// Remaining ties go by title, so the order doesn't change between fetches.
static NSComparisonResult CompareItemsOnDay(EventInfo *e1, EventInfo *e2)
{
    NSComparisonResult result;
    if (e1.isRealAllDay && e2.isRealAllDay) {
        result = CompletedLast(e1, e2);
        if (result == NSOrderedSame) result = [e1.item.calendar.title compare:e2.item.calendar.title];
    }
    else if (e1.isRealAllDay && !e2.isRealAllDay) { return NSOrderedAscending; }
    else if (!e1.isRealAllDay && e2.isRealAllDay) { return NSOrderedDescending; }
    else if (e1.isAllDay && e2.isAllDay) { result = [e1.item.calendar.title compare:e2.item.calendar.title];}
    else if (e1.isAllDay) { return NSOrderedAscending;  }
    else if (e2.isAllDay) { return NSOrderedDescending; }
    else {
        result = [e1.startDate compare:e2.startDate];
        if (result == NSOrderedSame) result = CompletedLast(e1, e2);
    }
    return result != NSOrderedSame ? result : [e1.item.title ?: @"" localizedStandardCompare:e2.item.title ?: @""];
}

// =========================================================================
// Reminders
// =========================================================================

// Return the date a reminder is due. A reminder may be due on a
// day without a time. Then *hasTime is NO, and the date is the
// start of that day in the local time zone, like an all-day event.
// If calendar isn't NULL, set it to the calendar the due date is in,
// for expanding a repeating reminder's later occurrences.
static NSDate *DueDateForReminder(EKReminder *reminder, BOOL *hasTime, NSCalendar **calendar)
{
    *hasTime = NO;
    if (reminder.dueDateComponents == nil) return nil;
    NSDateComponents *components = [reminder.dueDateComponents copy];
    *hasTime = components.hour != NSDateComponentUndefined;
    // The components carry their own calendar (usually Gregorian),
    // which may differ from the user's. A time is in the components'
    // time zone, if any. A day without a time is in the local one.
    NSCalendar *dueCalendar = [components.calendar ?: [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] copy];
    dueCalendar.timeZone = (*hasTime && components.timeZone) ? components.timeZone : [NSTimeZone localTimeZone];
    if (calendar) *calendar = dueCalendar;
    components.calendar = nil;
    components.timeZone = nil;
    return [dueCalendar dateFromComponents:components];
}

// Is reminder due at dueDate (which may be nil, for no due date)?
BOOL ReminderIsDue(EKReminder *reminder, NSDate *dueDate)
{
    BOOL hasTime;
    NSDate *date = DueDateForReminder(reminder, &hasTime, NULL);
    return date == dueDate || [date isEqualToDate:dueDate];
}

@implementation ReminderState

+ (instancetype)stateOfReminder:(EKReminder *)reminder
{
    ReminderState *state = [ReminderState new];
    BOOL hasTime;
    state.dueDateComponents   = [reminder.dueDateComponents copy];
    state.startDateComponents = [reminder.startDateComponents copy];
    state.dueDate             = DueDateForReminder(reminder, &hasTime, NULL);
    state.completionDate      = reminder.completionDate;
    state.alarmValues         = AlarmValuesOfReminder(reminder);
    state.occurrenceCount     = reminder.recurrenceRules.firstObject.recurrenceEnd.occurrenceCount;
    return state;
}

- (void)restoreReminder:(EKReminder *)reminder
{
    reminder.startDateComponents = self.startDateComponents;
    reminder.dueDateComponents   = self.dueDateComponents;
    // Put back the remaining count, which EventKit lowered. Otherwise
    // each check-off and undo would lose an occurrence. It must be a new
    // rule: EventKit doesn't save a changed end on a copy of the old one.
    // (The rule's first day of the week can't be set; it's only not the
    // default if another app set it.) Only for a single rule, which is
    // all Reminders makes, so another app's extra rules aren't lost.
    EKRecurrenceRule *rule = reminder.recurrenceRules.firstObject;
    if (reminder.recurrenceRules.count == 1 && self.occurrenceCount > 0 &&
        rule.recurrenceEnd.occurrenceCount != self.occurrenceCount) {
        EKRecurrenceEnd *end = [EKRecurrenceEnd recurrenceEndWithOccurrenceCount:self.occurrenceCount];
        reminder.recurrenceRules = @[[[EKRecurrenceRule alloc] initRecurrenceWithFrequency:rule.frequency interval:rule.interval daysOfTheWeek:rule.daysOfTheWeek daysOfTheMonth:rule.daysOfTheMonth monthsOfTheYear:rule.monthsOfTheYear weeksOfTheYear:rule.weeksOfTheYear daysOfTheYear:rule.daysOfTheYear setPositions:rule.setPositions end:end]];
    }
    // Rebuild the alarms only if they changed, so alarms we don't
    // need to touch keep everything about them. The store may return
    // them in a different order, so ignore order.
    NSArray *currentValues = AlarmValuesOfReminder(reminder);
    if (self.alarmValues == nil ||
        (currentValues && [[NSCountedSet setWithArray:currentValues] isEqual:[NSCountedSet setWithArray:self.alarmValues]])) {
        return;
    }
    for (EKAlarm *alarm in reminder.alarms) {
        [reminder removeAlarm:alarm];
    }
    for (NSDictionary *value in self.alarmValues) {
        EKAlarm *alarm = value[@"absoluteDate"]
            ? [EKAlarm alarmWithAbsoluteDate:value[@"absoluteDate"]]
            : [EKAlarm alarmWithRelativeOffset:[value[@"relativeOffset"] doubleValue]];
        alarm.emailAddress = value[@"emailAddress"];
        alarm.soundName    = value[@"soundName"];
        [reminder addAlarm:alarm];
    }
}

// Each alarm's time and action as a dictionary, or nil if the
// reminder has an alarm that can't be copied (e.g. location).
// An alarm's type follows from its emailAddress and soundName.
static NSArray<NSDictionary *> *AlarmValuesOfReminder(EKReminder *reminder)
{
    NSMutableArray *values = [NSMutableArray new];
    for (EKAlarm *alarm in reminder.alarms) {
        if (alarm.structuredLocation != nil) return nil;
        NSMutableDictionary *value = [NSMutableDictionary new];
        if (alarm.absoluteDate) value[@"absoluteDate"] = alarm.absoluteDate;
        else value[@"relativeOffset"] = @(alarm.relativeOffset);
        if (alarm.emailAddress) value[@"emailAddress"] = alarm.emailAddress;
        if (alarm.soundName) value[@"soundName"] = alarm.soundName;
        [values addObject:value];
    }
    return values;
}

@end

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
            || (hostIs(@"vk.com") && [path hasPrefix:@"/call/"])
            || (hostIs(@"max.ru") && [path hasPrefix:@"/joincall/"])) {
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
