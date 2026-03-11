//
//  EventCenter.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <os/log.h>
#import <AppKit/NSWorkspace.h>
#import "EventCenter.h"
#import "ContactEventManager.h"
#import "Itsycal.h"

// NSUserDefaults key for array of selected calendar IDs.
static NSString *kSelectedCalendars = @"SelectedCalendars";

// Properties auto-synthesized.
@implementation CalendarInfo @end
@implementation EventInfo    @end

@implementation EventCenter {                      // Accessed on:
    EKEventStore         *_store;
    NSCalendar           *_cal;
    NSMutableDictionary  *_eventsForDate;          // _queueWork
    NSDictionary         *_filteredEventsForDate;  // _queueIsol
    NSMutableIndexSet    *_previouslyFetchedDates; // _queueWork
    NSArray              *_sourcesAndCalendars;    // _queueIsol2
    ContactEventManager  *_contactEventManager;
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
        
        // Create queues with explicit QoS to avoid priority inversions
        // Use UTILITY QoS for event fetching - users expect to see events reasonably quickly
        dispatch_queue_attr_t queueAttr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        _queueWork = dispatch_queue_create("com.mowglii.Itsycal.queueWork", queueAttr);
        
        // Isolation queues are accessed from main thread, so use USER_INITIATED QoS
        queueAttr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
        _queueIsol = dispatch_queue_create("com.mowglii.Itsycal.queueIsol", queueAttr);
        _queueIsol2 = dispatch_queue_create("com.mowglii.Itsycal.queueIsol2", queueAttr);
        
        _store = [EKEventStore new];
        
        // Initialize contact event manager
        _contactEventManager = [[ContactEventManager alloc] initWithCalendar:calendar];
        
        if (@available(macOS 14.0, *)) {
            [_store requestFullAccessToEventsWithCompletion:requestCompletionHandler];
        } else {
            [_store requestAccessToEntityType:EKEntityTypeEvent completion:requestCompletionHandler];
        }

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

- (ContactEventManager *)contactEventManager {
    return _contactEventManager;
}

- (BOOL)calendarAccessGranted {
    if (@available(macOS 14.0, *)) {
        return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusFullAccess;
    } else {
        return [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusAuthorized;
    }
}

- (NSString *)defaultCalendarIdentifier {
    EKCalendar *cal = [_store defaultCalendarForNewEvents];
    return cal.calendarIdentifier;
}

- (EKEvent *)newEvent {
    return [EKEvent eventWithEventStore:_store];
}

- (EKEvent *)refreshEvent:(EKEvent *)event {
    // If the event's eventStore is nil, refresh it from our store
    if (!event || !event.eventIdentifier) {
        return event;
    }
    // Get a fresh copy of the event from the store
    return [_store eventWithIdentifier:event.eventIdentifier];
}

- (BOOL)saveEvent:(EKEvent *)event error:(NSError **)error {
    return [_store saveEvent:event span:EKSpanThisEvent commit:YES error:error];
}

- (BOOL)removeEvent:(EKEvent *)event span:(EKSpan)span error:(NSError **)error {
    return [_store removeEvent:event span:span commit:YES error:error];
}

- (void)updateSelectedCalendarsForIdentifier:(NSString *)identifier selected:(BOOL)selected {
    //os_log(OS_LOG_DEFAULT, "%s", __FUNCTION__);
    // The user has selected/unselected a calendar in Prefs.
    // Update the kSelectedCalendars array in NSUserDefaults.
    __block NSMutableArray *selectedCalendars = [NSMutableArray new];
    dispatch_sync(_queueIsol2, ^{
        for (id obj in self->_sourcesAndCalendars) {
            if ([obj isKindOfClass:[CalendarInfo class]]) {
                CalendarInfo *info = obj;
                if ([info.calendar.calendarIdentifier isEqualToString:identifier]) {
                    info.selected = selected;
                }
                if (info.selected) {
                    [selectedCalendars addObject:info.calendar.calendarIdentifier];
                }
            }
        }
    });
    [[NSUserDefaults standardUserDefaults] setObject:selectedCalendars forKey:kSelectedCalendars];
    
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

#pragma mark - Private (GCD thread pool)

- (void)_fetchSourcesAndCalendars {
    //os_log(OS_LOG_DEFAULT, " %s", __FUNCTION__);
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
        NSString *calendarSourceTitle = calendar.source.title;
        // (!) Should never hit this case, but MacOS 13 sometimes returns
        // nil for non-iCloud source titles. Use a dummy title instead.
        if (!calendar.source.title) calendarSourceTitle = @"???";
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
    dispatch_async(_queueIsol2, ^{
        self->_sourcesAndCalendars = [NSArray arrayWithArray:sourcesAndCalendars];
    });
}

- (NSArray *)_validCalendars
{
    // Valid calendars are calendars in _sourcesAndCalendars.
    // They have been filtered to remove calendars where the color is nil.
    // See -_fetchSourcesAndCalendars
    __block NSMutableArray *calendars = [NSMutableArray new];
    dispatch_sync(_queueIsol2, ^{
        for (id obj in self->_sourcesAndCalendars) {
            if ([obj isKindOfClass:[CalendarInfo class]]) {
                CalendarInfo *calInfo = obj;
                [calendars addObject:calInfo.calendar];
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
    NSArray *cals = [self _validCalendars];
    NSPredicate *predicate = [_store predicateForEventsWithStartDate:startDate endDate:endDate calendars:cals];
    NSArray *events = [_store eventsMatchingPredicate:predicate];
    NSMutableDictionary *eventsForDate = [NSMutableDictionary new];
    
    // Iterate over events matching startDate/endDate. We will
    // populate a dictionary, eventsForDate, that maps each date
    // to an array of events that fall on that date.
    for (EKEvent *event in events) {
        
        // Skip events the current user has declined.
        // Use 'valueForKey' to get private 'participationStatus' property.
        // This is much faster than accessing the 'attendees' property
        // and then looping over the participants to see if the current
        // user has declined the event.
        if (event.hasAttendees &&
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
    
    // eventsForDate is a dict that maps dates to an array of EventInfo objects.
    // We'll sort after merging contact events to avoid sorting twice.
    
    // Merge in contact events if enabled
    BOOL showContactEvents = [[NSUserDefaults standardUserDefaults] boolForKey:kShowContactEvents];
    
    if (showContactEvents && _contactEventManager.contactsAccessGranted) {
        // Use a semaphore to wait for the async contact events fetch
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block NSDictionary *contactEvents = nil;
        
        [_contactEventManager contactEventsFromDate:startMoDate toDate:endMoDate completion:^(NSDictionary<NSDate *,NSArray<EventInfo *> *> * _Nonnull events) {
            contactEvents = events;
            dispatch_semaphore_signal(semaphore);
        }];
        
        // Wait for the async operation to complete
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        // Merge contact events into eventsForDate
        for (NSDate *date in contactEvents) {
            if (eventsForDate[date] == nil) {
                eventsForDate[date] = [NSMutableArray new];
            }
            [eventsForDate[date] addObjectsFromArray:contactEvents[date]];
        }
    } else if (showContactEvents) {
        NSLog(@"[EventCenter] Contact events enabled but access not granted yet");
    }
    
    // Sort all events: contact events first (alphabetically), then calendar events
    // Calendar events are sorted with all-day first (by calendar title), then by start time
    for (NSDate *date in eventsForDate) {
        [eventsForDate[date] sortUsingComparator:^NSComparisonResult(EventInfo *e1, EventInfo *e2) {
            // Contact events always come first
            if (e1.isContactEvent && !e2.isContactEvent) {
                return NSOrderedAscending;
            } else if (!e1.isContactEvent && e2.isContactEvent) {
                return NSOrderedDescending;
            } else if (e1.isContactEvent && e2.isContactEvent) {
                // Both are contact events, sort alphabetically by title
                return [e1.contactEventTitle compare:e2.contactEventTitle];
            } else {
                // Both are calendar events, sort by all-day status then time
                if (e1.event.isAllDay && e2.event.isAllDay)  { return [e1.event.calendar.title compare:e2.event.calendar.title];}
                else if (e1.event.isAllDay && !e2.event.isAllDay) { return NSOrderedAscending; }
                else if (!e1.event.isAllDay && e2.event.isAllDay) { return NSOrderedDescending; }
                else if (e1.isAllDay && e2.isAllDay) { return [e1.event.calendar.title compare:e2.event.calendar.title];}
                else if (e1.isAllDay) { return NSOrderedAscending;  }
                else if (e2.isAllDay) { return NSOrderedDescending; }
                else { return [e1.event.startDate compare:e2.event.startDate]; }
            }
        }];
    }
    
    [_eventsForDate addEntriesFromDictionary:eventsForDate];
    [self _filterEvents];
}

- (void)_filterEvents {
    //os_log(OS_LOG_DEFAULT, " %s", __FUNCTION__);
    NSMutableDictionary *filteredEventsForDate = [NSMutableDictionary new];
    NSArray *selectedCalendars = [[NSUserDefaults standardUserDefaults] arrayForKey:kSelectedCalendars];
    for (NSDate *date in _eventsForDate) {
        for (EventInfo *info in _eventsForDate[date]) {
            // Include contact events (which have nil event property) if contact events are enabled
            BOOL isContactEvent = info.isContactEvent && info.event == nil;
            BOOL showContactEvents = [[NSUserDefaults standardUserDefaults] boolForKey:kShowContactEvents];
            
            if (isContactEvent && showContactEvents) {
                if (filteredEventsForDate[date] == nil) {
                    filteredEventsForDate[date] = [NSMutableArray new];
                }
                [filteredEventsForDate[date] addObject:info];
            }
            else if (!isContactEvent && [selectedCalendars containsObject:info.event.calendar.calendarIdentifier]) {
                if (filteredEventsForDate[date] == nil) {
                    filteredEventsForDate[date] = [NSMutableArray new];
                }
                // Check if there is a virtual meeting (e.g. Zoom) link.
                // We limit this check to filtered events in an
                // attempt to limit how much text processing we do.
                [self checkForZoomURL:info];
                [filteredEventsForDate[date] addObject:info];
            }
        }
    }
    dispatch_async(_queueIsol, ^{
        self->_filteredEventsForDate = [filteredEventsForDate copy];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate eventCenterEventsChanged];
    });
}

- (void)checkForZoomURL:(EventInfo *)info {
    static NSDataDetector *linkDetector = nil;
    if (linkDetector == nil) {
        linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
    }
    void (^GetZoomURL)(NSString*) = ^(NSString *text) {
        [linkDetector enumerateMatchesInString:text options:kNilOptions range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
            NSString *link = result.URL.absoluteString;
            if (   [link containsString:@"zoom.us/j/"]
                || [link containsString:@"zoom.us/s/"]
                || [link containsString:@"zoom.us/w/"]
                || [link containsString:@"zoom.us/my/"]
                || [link containsString:@"zoomgov.com/j/"]
                || [link containsString:@"zoomgov.com/s/"]
                || [link containsString:@"zoomgov.com/w/"]
                || [link containsString:@"zoomgov.com/my/"]) {
                info.zoomURL = result.URL;
                // Test if user has the Zoom app and, if so, create a Zoom app link.
                if ([NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"zoommtg://"]]) {
                    link = [link stringByReplacingOccurrencesOfString:@"https://" withString:@"zoommtg://"];
                    link = [link stringByReplacingOccurrencesOfString:@"?" withString:@"&"];
                    link = [link stringByReplacingOccurrencesOfString:@"/j/" withString:@"/join?confno="];
                    link = [link stringByReplacingOccurrencesOfString:@"/s/" withString:@"/join?confno="];
                    link = [link stringByReplacingOccurrencesOfString:@"/w/" withString:@"/join?confno="];
                    NSURL *appLink = [NSURL URLWithString:link];
                    if (appLink) info.zoomURL = appLink;
                }
            }
            else if ([link containsString:@"teams.microsoft.com/l/meetup-join/"]) {
                info.zoomURL = result.URL;
                // Test if user has the Teams app and, if so, create a Teams app link.
                if ([NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"msteams://"]]) {
                    link = [link stringByReplacingOccurrencesOfString:@"https://" withString:@"msteams://"];
                    NSURL *appLink = [NSURL URLWithString:link];
                    if (appLink) info.zoomURL = appLink;
                }
            }
            else if ([link containsString:@"chime.aws/"]) {
                info.zoomURL = result.URL;
                // Test if user has the Chime app, and if so, create a Chime app link.
                if ([NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"chime://"]]) {
                    link = [link stringByReplacingOccurrencesOfString:@"https://chime.aws/" withString:@"chime://meeting?pin="];
                    NSURL *appLink = [NSURL URLWithString:link];
                    if (appLink) info.zoomURL = appLink;
                }
            }
            else if (   [link containsString:@"zoommtg://"]
                     || [link containsString:@"msteams://"]
                     || [link containsString:@"chime://"]
                     || [link containsString:@"meet.google.com/"]
                     || [link containsString:@"hangouts.google.com/"]
                     || [link containsString:@"webex.com/"]
                     || [link containsString:@"gotomeeting.com/join"]
                     || [link containsString:@"ringcentral.com/j"]
                     || [link containsString:@"bigbluebutton.org/gl"]
                     || [link containsString:@"https://bigbluebutton."]
                     || [link containsString:@"https://bbb."]
                     || [link containsString:@"https://meet.jit.si/"]
                     || [link containsString:@"indigo.collocall.de"]
                     || [link containsString:@"public.senfcall.de"]
                     || [link containsString:@"facetime.apple.com/join"]
                     || [link containsString:@"workplace.com/meet"]
                     || [link containsString:@"youcanbook.me/zoom/"]
                     || [link containsString:@"vk.com/call/"]) {
                info.zoomURL = result.URL;
            }
            *stop = info.zoomURL != nil;
        }];
    };
    info.zoomURL = nil;
    if (info.event.location) GetZoomURL(info.event.location);
    if (info.zoomURL) return;
    if (info.event.URL) GetZoomURL(info.event.URL.absoluteString);
    if (info.zoomURL) return;
    if (info.event.hasNotes && info.event.notes) GetZoomURL(info.event.notes);
}

@end
