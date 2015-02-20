//
//  EventCenter.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <EventKit/EventKit.h>
#import "EventCenter.h"

// NSUserDefaults key for array of selected calendar IDs.
static NSString *kSelectedCalendars = @"SelectedCalendars";

// Properties auto-synthesized.
@implementation CalendarInfo @end
@implementation EventInfo    @end

@implementation EventCenter
{
    NSCalendar           *_cal;
    EKEventStore         *_store;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeChanged:) name:EKEventStoreChangedNotification object:_store];
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
    NSMutableArray *cleanSelectedCalendars = [NSMutableArray new];

    // Make an array of source titles and calendar info.
    // Also create a clean array of selected calendar identifiers for
    // NSUserDefaults. We do this in case the user has resynced their
    // calendars and the calendar identifiers have changed.
    NSMutableArray *sourcesAndCalendars = [NSMutableArray new];
    NSString *currentSourceTitle = @"";
    for (EKCalendar *calendar in calendars) {
        if (![calendar.source.title isEqualToString:currentSourceTitle]) {
            [sourcesAndCalendars addObject:calendar.source.title];
            currentSourceTitle = calendar.source.title;
        }
        CalendarInfo *calInfo = [CalendarInfo new];
        calInfo.title      = calendar.title;
        calInfo.identifier = calendar.calendarIdentifier;
        calInfo.color      = calendar.color;
        calInfo.selected   = selectedCalendars ? [selectedCalendars containsObject:calInfo.identifier] : NO;
        [sourcesAndCalendars addObject:calInfo];
        if (calInfo.selected) {
            [cleanSelectedCalendars addObject:calInfo.identifier];
        }
    }
    _sourcesAndCalendars = [NSArray arrayWithArray:sourcesAndCalendars];
    [defaults setObject:cleanSelectedCalendars forKey:kSelectedCalendars];
    
    [self.delegate eventCenterSourcesAndCalendarsChanged];
}

- (void)updateSelectedCalendars
{
    // The user has selected/unselected a calendar in Prefs.
    // Update the kSelectedCalendars array in NSUserDefaults.
    NSMutableArray *selectedCalendars = [NSMutableArray new];
    for (id obj in self.sourcesAndCalendars) {
        if ([obj isKindOfClass:[CalendarInfo class]] &&
            [(CalendarInfo *)obj selected]) {
            [selectedCalendars addObject:[(CalendarInfo *)obj identifier]];
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

    NSDate *nsDate = [_cal startOfDayForDate:[self nsDateFromMoDate:date]];
    return _filteredEventsForDate[nsDate];
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
                
                CFTimeInterval t = CACurrentMediaTime();
                [self fetchEventsWithStartDate:startDate endDate:endDate];
                NSLog(@"t=%f", CACurrentMediaTime() - t);
                
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
    NSDate *startDate = [self nsDateFromMoDate:startMoDate];
    NSDate *endDate   = [self nsDateFromMoDate:endMoDate];
    NSPredicate *predicate = [_store predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
    NSArray *events = [_store eventsMatchingPredicate:predicate];
    NSMutableDictionary *eventsForDate = [NSMutableDictionary new];
    
    // Iterate over events matching startDate/endDate. We will
    // populate a dictionary, eventsForDate, that maps each date
    // to an array of events that fall on that date.
    for (EKEvent *event in events) {

// TODO: COMMENTING THIS OUT FOR NOW BECAUSE IT IS INEXPLICABLY SLOW.
//       IT IS JUST AS SLOW EVEN IF THE BODY OF THE LOOP IS REMOVED.
//
//        // Skip events the current user has declined.
//        for (EKParticipant *participant in event.attendees) {
//            if (participant.isCurrentUser &&
//                participant.participantStatus == EKParticipantStatusDeclined) {
//                return; // this is like 'continue' in a for-loop
//            }
//        }

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
            info.title       = event.title;
            info.startDate   = event.startDate;
            info.endDate     = event.endDate;
            info.isStartDate = ([_cal isDate:date inSameDayAsDate:event.startDate] &&
                                [event.endDate compare:nextDate] == NSOrderedDescending);
            info.isEndDate   = ([_cal isDate:date inSameDayAsDate:event.endDate] &&
                                [event.startDate compare:date] == NSOrderedAscending);
            info.isAllDay    = (event.allDay ||
                                ([event.startDate compare:date] == NSOrderedAscending &&
                                 [event.endDate compare:nextDate] == NSOrderedDescending));
            info.calendarColor = event.calendar.color;
            info.calendarIdentifier = event.calendar.calendarIdentifier;
            
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
            else    { return [e1.startDate compare:e2.startDate]; }
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
            if ([selectedCalendars containsObject:info.calendarIdentifier]) {
                if (filteredEventsForDates[date] == nil) {
                    filteredEventsForDates[date] = [NSMutableArray new];
                }
                [filteredEventsForDates[date] addObject:info];
            }
        }
    }
    _filteredEventsForDate = [filteredEventsForDates copy];
    
//    for (NSDate *d in _filteredEventsForDates) {
//        NSLog(@"%@", d);
//        for (EventInfo *e in _filteredEventsForDates[d]) {
//            NSLog(@"    %@", e.title);
//        }
//    }
}

#pragma mark -
#pragma mark Store changed notification

- (void)storeChanged:(NSNotification *)note
{
    // The system told us the event store has changed so
    // we have to refetch everything.
    
    _eventsForDate = [NSMutableDictionary new];

    [self fetchSourcesAndCalendars];
    [self fetchEvents];
}

#pragma mark -
#pragma mark Utilities

- (NSDate *)nsDateFromMoDate:(MoDate)moDate
{
    return [_cal dateWithEra:1 year:moDate.year month:moDate.month+1 day:moDate.day hour:0 minute:0 second:0 nanosecond:0];
}

- (MoDate)moDateFromNSDate:(NSDate *)nsDate
{
    NSInteger year, month, day;
    [_cal getEra:NULL year:&year month:&month day:&day fromDate:nsDate];
    return MakeDate((int)year, (int)month-1, (int)day);
}

@end
