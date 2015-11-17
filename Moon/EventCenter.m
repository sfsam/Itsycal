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

@implementation EventCenter
{
    NSCalendar           *_cal;
    NSMutableDictionary  *_eventsForDate;
    NSDictionary         *_filteredEventsForDate;
    dispatch_queue_t      _queue;

}

- (instancetype)initWithCalendar:(NSCalendar *)calendar delegate:(id<EventCenterDelegate>)delegate
{
    self = [super init];
    if (self) {
        _cal = calendar;
        _delegate = delegate;
        _sourcesAndCalendars = [NSArray new];
        _eventsForDate  = [NSMutableDictionary new];
        _filteredEventsForDate = [NSDictionary new];
        _queue = dispatch_queue_create("com.mowglii.Itsycal.eventQueue", DISPATCH_QUEUE_SERIAL);
        _store = [EKEventStore new];
        [_store requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
            if (granted) {
                [self fetchSourcesAndCalendars];
                [self fetchEvents];
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
        [[NSNotificationCenter defaultCenter] addObserverForName:EKEventStoreChangedNotification object:_store queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            [self refetchAll];
        }];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)calendarAccessGranted
{
    return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusAuthorized;
}

- (NSString *)defaultCalendarIdentifier
{
    EKCalendar *cal = [_store defaultCalendarForNewEvents];
    return cal.calendarIdentifier;
}

#pragma mark -
#pragma mark Calendars

- (void)fetchSourcesAndCalendars
{
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

- (void)updateSelectedCalendars
{
    // The user has selected/unselected a calendar in Prefs.
    // Update the kSelectedCalendars array in NSUserDefaults.
    NSMutableArray *selectedCalendars = [NSMutableArray new];
    for (id obj in self.sourcesAndCalendars) {
        if ([obj isKindOfClass:[CalendarInfo class]] &&
            [(CalendarInfo *)obj selected]) {
            CalendarInfo *info = obj;
            [selectedCalendars addObject:info.calendar.calendarIdentifier];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:selectedCalendars forKey:kSelectedCalendars];
    
    // Filter events based on new calendar selection.
    [self filterEvents];
    [self.delegate eventCenterEventsChanged];
}

#pragma mark -
#pragma mark Events

- (NSArray *)eventsForDate:(MoDate)date
{
    // TODO: Do we need to check if theDate is in the range
    //       of events we've already fetched?

    NSDate *nsDate = MakeNSDateWithDate(date, _cal);
    return _filteredEventsForDate[nsDate];
}

- (NSArray *)datesAndEventsForDate:(MoDate)date days:(NSInteger)days
{
    NSMutableArray *datesAndEvents = [NSMutableArray new];
    MoDate endDate = AddDaysToDate(days, date);
    while (CompareDates(date, endDate) < 0) {
        NSDate *nsDate = MakeNSDateWithDate(date, _cal);
        NSArray *events = _filteredEventsForDate[nsDate];
        if (events != nil) {
            [datesAndEvents addObject:nsDate];
            [datesAndEvents addObjectsFromArray:events];
        }
        date = AddDaysToDate(1, date);
    }
    return datesAndEvents;
}

- (void)fetchEvents
{
    MoDate startDate = [self.delegate fetchStartDate];
    MoDate endDate   = [self.delegate fetchEndDate];
    
    dispatch_async(_queue, ^{
        @autoreleasepool {
            
            // Because fetchEventsWithStartDate:endDate: is called on a serial
            // dispatch queue, by the time it is invoked, the user may have
            // navigated away from the month for which it is fetching events.
            // If so, we skip it so that the next block of work on the queue
            // can be processed.
            
            MoDate currentStartDate = [self.delegate fetchStartDate];
            if (CompareDates(startDate, currentStartDate) == 0) {
                
                [self fetchEventsWithStartDate:startDate endDate:endDate];
                
                // We do a similar check here since the fetch we just completed
                // is slow. It may be the case that the user has navigated away
                // from that month. If so, no need to tell the delegate about
                // this fetch since it is for a montht that is no longer
                // displaying.
                
                MoDate currentStartDate = [self.delegate fetchStartDate];
                if (CompareDates(startDate, currentStartDate) == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate eventCenterEventsChanged];
                    });
                }
                else {
                    NSLog(@"==== START DATES DIFFER, SKIP DELEGATE CALLBACK ====");
                }
            }
            else {
                NSLog(@"**** START DATES DIFFER, SKIP ENTIRE BLOCK ****");
            }
        }
    });
}

- (void)fetchEventsWithStartDate:(MoDate)startMoDate endDate:(MoDate)endMoDate
{
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
    [self filterEvents];
}

- (void)filterEvents
{
    NSMutableDictionary *filteredEventsForDates = [NSMutableDictionary new];
    NSArray *selectedCalendars = [[NSUserDefaults standardUserDefaults] arrayForKey:kSelectedCalendars];
    for (NSDate *date in _eventsForDate) {
        for (EventInfo *info in _eventsForDate[date]) {
            if ([selectedCalendars containsObject:info.event.calendar.calendarIdentifier]) {
                if (filteredEventsForDates[date] == nil) {
                    filteredEventsForDates[date] = [NSMutableArray new];
                }
                [filteredEventsForDates[date] addObject:info];
            }
        }
    }
    _filteredEventsForDate = [filteredEventsForDates copy];
}

- (void)refetchAll
{
    // Either the system told us the event store has changed or
    // we were called by the main controller. Clear the cache
    // and refetch everything.
    
    _eventsForDate = [NSMutableDictionary new];

    [self fetchSourcesAndCalendars];
    [self fetchEvents];
}

@end
