//
//  EventCenter.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "EventCenter.h"

// NSUserDefaults key for array of selected calendar IDs.
static NSString *kSelectedCalendars = @"SelectedCalendars";

// Properties auto-synthesized.
@implementation CalendarInfo @end
@implementation EventInfo    @end

@implementation EventCenter {                      // Accessed on:
    NSCalendar           *_cal;
    NSMutableDictionary  *_eventsForDate;          // _queueWork
    NSDictionary         *_filteredEventsForDate;  // _queueIsol
    NSMutableIndexSet    *_previouslyFetchedDates; // main thread
    //NSArray            *_sourcesAndCalendars     // main thread
    dispatch_queue_t      _queueWork;
    dispatch_queue_t      _queueIsol;
}

- (instancetype)initWithCalendar:(NSCalendar *)calendar delegate:(id<EventCenterDelegate>)delegate {
    self = [super init];
    if (self) {
        _cal = calendar;
        _delegate = delegate;
        _sourcesAndCalendars = [NSArray new];
        _eventsForDate  = [NSMutableDictionary new];
        _filteredEventsForDate = [NSDictionary new];
        _previouslyFetchedDates = [NSMutableIndexSet new];
        _queueWork = dispatch_queue_create("com.mowglii.Itsycal.queueWork", DISPATCH_QUEUE_SERIAL);
        _queueIsol = dispatch_queue_create("com.mowglii.Itsycal.queueIsol", DISPATCH_QUEUE_CONCURRENT);
        _store = [EKEventStore new];
        [_store requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
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
        }];

        // Refetch everything when the event store has changed.
        // Use weakSelf so -dealloc can be called after user calls
        // -resetEventCenter in ViewController.
        __weak __typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:EKEventStoreChangedNotification object:_store queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            // Coalesce notifications arriving within 1 second of
            // each other because some actions, like creating or
            // deleting events, generate multiple notifications.
            [NSObject cancelPreviousPerformRequestsWithTarget:weakSelf selector:@selector(refetchAll) object:nil];
            [weakSelf performSelector:@selector(refetchAll) withObject:nil afterDelay:1];
        }];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public properties (main thread)

- (BOOL)calendarAccessGranted {
    return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusAuthorized;
}

- (NSString *)defaultCalendarIdentifier {
    EKCalendar *cal = [_store defaultCalendarForNewEvents];
    return cal.calendarIdentifier;
}

#pragma mark - Public methods (main thread)

- (void)updateSelectedCalendars {
    // The user has selected/unselected a calendar in Prefs.
    // Update the kSelectedCalendars array in NSUserDefaults.
    NSMutableArray *selectedCalendars = [NSMutableArray new];
    for (id obj in _sourcesAndCalendars) {
        if ([obj isKindOfClass:[CalendarInfo class]] &&
            [(CalendarInfo *)obj selected]) {
            CalendarInfo *info = obj;
            [selectedCalendars addObject:info.calendar.calendarIdentifier];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:selectedCalendars forKey:kSelectedCalendars];
    
    // Filter events based on new calendar selection.
    dispatch_async(_queueWork, ^{
        [self _filterEvents];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate eventCenterEventsChanged];
        });
    });
}

- (NSArray *)eventsForDate:(MoDate)date {
    if (![_previouslyFetchedDates containsIndex:date.julian]) return nil;
    NSDate *nsDate = MakeNSDateWithDate(date, _cal);
    __block NSArray *filteredEventsForNSDate;
    dispatch_sync(_queueIsol, ^{
        filteredEventsForNSDate = [self->_filteredEventsForDate[nsDate] copy];
    });
    return filteredEventsForNSDate;
}

- (NSArray *)datesAndEventsForDate:(MoDate)date days:(NSInteger)days {
    __block NSDictionary *filteredEventsForDate;
    dispatch_sync(_queueIsol, ^{
        filteredEventsForDate = [self->_filteredEventsForDate copy];
    });
    NSMutableArray *datesAndEvents = [NSMutableArray new];
    MoDate endDate = AddDaysToDate(days, date);
    while (CompareDates(date, endDate) < 0) {
        NSDate *nsDate = MakeNSDateWithDate(date, _cal);
        NSArray *events = filteredEventsForDate[nsDate];
        if (events != nil) {
            [datesAndEvents addObject:nsDate];
            [datesAndEvents addObjectsFromArray:events];
        }
        date = AddDaysToDate(1, date);
    }
    return datesAndEvents;
}

- (void)fetchEvents {
    [self _fetchEvents:NO];
}

- (void)refetchAll {
    // Either the system told us the event store has changed or
    // we were called by the main controller. Clear the cache
    // and refetch everything.
    _previouslyFetchedDates = [NSMutableIndexSet new];
    [_store reset];
    [self _fetchSourcesAndCalendars];
    [self _fetchEvents:YES];
}

#pragma mark - Private methods (main thread)

- (void)_fetchSourcesAndCalendars {
    // Get an array of the user's calendars sorted first by
    // source title and then by calendar title.
    NSArray *calendars = [[_store calendarsForEntityType:EKEntityTypeEvent] sortedArrayUsingComparator:^NSComparisonResult(EKCalendar *cal1, EKCalendar *cal2) {
        if ([cal1.source.sourceIdentifier isEqualToString:cal2.source.sourceIdentifier]) {
            return [cal1.title compare:cal2.title];
        }
        else {
            return [cal1.source.title compare:cal2.source.title];
        }
    }];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSSet *selectedCalendars = [NSSet setWithArray:[defaults arrayForKey:kSelectedCalendars]];
    
    // Make an array of source titles and calendar info.
    NSMutableArray *sourcesAndCalendars = [NSMutableArray new];
    NSString *currentSourceTitle = @"";
    for (EKCalendar *calendar in calendars) {
        if (![calendar.source.title isEqualToString:currentSourceTitle]) {
            [sourcesAndCalendars addObject:calendar.source.title];
            currentSourceTitle = calendar.source.title;
        }
        CalendarInfo *calInfo = [CalendarInfo new];
        calInfo.calendar = calendar;
        calInfo.selected = selectedCalendars ? [selectedCalendars containsObject:calendar.calendarIdentifier] : NO;
        [sourcesAndCalendars addObject:calInfo];
    }
    _sourcesAndCalendars = [NSArray arrayWithArray:sourcesAndCalendars];
}

- (void)_fetchEvents:(BOOL)refetch {
    MoDate startMoDate = [self.delegate fetchStartDate];
    MoDate endMoDate   = [self.delegate fetchEndDate];
    
    // Return immediately if we've already fetched for this date range.
    NSRange dateRange = NSMakeRange(startMoDate.julian, endMoDate.julian - startMoDate.julian);
    if ([_previouslyFetchedDates containsIndexesInRange:dateRange]) return;
    
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
    
    // Finally, fetch.
    @autoreleasepool {
        dispatch_async(_queueWork, ^{
            if (refetch) {
                self->_eventsForDate = [NSMutableDictionary new];
            }
            [self _fetchEventsWithStartDate:startMoDate endDate:endMoDate];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate eventCenterEventsChanged];
            });
        });
    }
}

#pragma mark - Private methods (GCD thread pool)

- (void)_fetchEventsWithStartDate:(MoDate)startMoDate endDate:(MoDate)endMoDate {
    NSDate *startDate = MakeNSDateWithDate(startMoDate, _cal);
    NSDate *endDate   = MakeNSDateWithDate(endMoDate,   _cal);
    NSPredicate *predicate = [_store predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
    NSArray *events = [_store eventsMatchingPredicate:predicate];
    NSMutableDictionary *eventsForDate = [NSMutableDictionary new];
    
    // Iterate over events matching startDate/endDate. We will
    // populate a dictionary, eventsForDate, that maps each date
    // to an array of events that fall on that date.
    for (EKEvent *event in events) {
        
        // Skip events the current user has declined.
        // This code is very slow. Apparently, loading the 'attendees'
        // property is time consuming. We avoid some of that by first
        // checking the 'hasAttendees' property. But events that do
        // have attendees will be slow to process.
        BOOL skipEventBecauseUserDeclinedIt = NO;
        if (event.hasAttendees) {
            for (EKParticipant *participant in event.attendees) {
                if (participant.isCurrentUser &&
                    participant.participantStatus == EKParticipantStatusDeclined) {
                    skipEventBecauseUserDeclinedIt = YES;
                    break; // break out of inner loop and...
                }
            }
        }
        if (skipEventBecauseUserDeclinedIt) continue; // ...continue outer loop
        
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
            info.isStartDate = ([_cal isDate:date inSameDayAsDate:event.startDate] &&
                                [event.endDate compare:nextDate] == NSOrderedDescending);
            info.isEndDate   = ([_cal isDate:date inSameDayAsDate:event.endDate] &&
                                [event.startDate compare:date] == NSOrderedAscending);
            info.isAllDay    = (event.allDay ||
                                ([event.startDate compare:date] == NSOrderedAscending &&
                                 [event.endDate compare:nextDate] == NSOrderedDescending));
            info.isSingleDay = (event.isAllDay &&
                                [event.startDate compare:date] == NSOrderedSame &&
                                [event.endDate compare:nextDate] == NSOrderedSame);
            // ...and add it to the array in eventsForDate.
            if (eventsForDate[date] == nil) {
                eventsForDate[date] = [NSMutableArray new];
            }
            [eventsForDate[date] addObject:info];
            
            date = nextDate;
        }
    }
    
    // eventsForDate is a dict that maps dates to an array of EventInfo objects.
    // Sort those arrays so that AllDay events are first,
    // then sort by startTime.
    for (NSDate *date in eventsForDate) {
        [eventsForDate[date] sortUsingComparator:^NSComparisonResult(EventInfo *e1, EventInfo *e2) {
            if      (e1.isAllDay == YES) { return NSOrderedAscending;  }
            else if (e2.isAllDay == YES) { return NSOrderedDescending; }
            else    { return [e1.event.startDate compare:e2.event.startDate]; }
        }];
    }
    
    [_eventsForDate addEntriesFromDictionary:eventsForDate];
    [self _filterEvents];
}

- (void)_filterEvents {
    NSMutableDictionary *filteredEventsForDate = [NSMutableDictionary new];
    NSArray *selectedCalendars = [[NSUserDefaults standardUserDefaults] arrayForKey:kSelectedCalendars];
    for (NSDate *date in _eventsForDate) {
        for (EventInfo *info in _eventsForDate[date]) {
            if ([selectedCalendars containsObject:info.event.calendar.calendarIdentifier]) {
                if (filteredEventsForDate[date] == nil) {
                    filteredEventsForDate[date] = [NSMutableArray new];
                }
                [filteredEventsForDate[date] addObject:info];
            }
        }
    }
    dispatch_barrier_async(_queueIsol, ^{
        self->_filteredEventsForDate = [filteredEventsForDate copy];
    });
}

@end
