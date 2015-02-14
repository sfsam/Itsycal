//
//  EventCenter.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/12/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <EventKit/EventKit.h>
#import "EventCenter.h"

// NSUserDefaults key for array of selected calendar IDs.
static NSString *kSelectedCalendars = @"SelectedCalendars";

// Properties auto-synthesized.
@implementation CalendarInfo @end

@implementation EventCenter
{
    NSCalendar    *_cal;
    EKEventStore  *_store;
}

- (instancetype)initWithCalendar:(NSCalendar *)calendar delegate:(id<EventCenterDelegate>)delegate
{
    self = [super init];
    if (self) {
        _cal = calendar;
        _delegate = delegate;
        _sourcesAndCalendars = [NSArray new];
        _store = [EKEventStore new];
        [_store requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
            if (granted) {
                [self fetchSourcesAndCalendars];
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
    __block NSString *currentSourceTitle = @"";
    [calendars enumerateObjectsUsingBlock:^(EKCalendar *cal, NSUInteger idx, BOOL *stop) {
        if (![cal.source.title isEqualToString:currentSourceTitle]) {
            [sourcesAndCalendars addObject:cal.source.title];
            currentSourceTitle = cal.source.title;
        }
        CalendarInfo *calInfo = [CalendarInfo new];
        calInfo.title      = cal.title;
        calInfo.identifier = cal.calendarIdentifier;
        calInfo.color      = cal.color;
        calInfo.selected   = selectedCalendars ? [selectedCalendars containsObject:calInfo.identifier] : NO;
        [sourcesAndCalendars addObject:calInfo];
        if (calInfo.selected) {
            [cleanSelectedCalendars addObject:calInfo.identifier];
        }
    }];
    _sourcesAndCalendars = [NSArray arrayWithArray:sourcesAndCalendars];
    [defaults setObject:cleanSelectedCalendars forKey:kSelectedCalendars];
    
    [self.delegate eventCenterSourcesAndCalendarsChanged];
}

- (void)updateSelectedCalendars
{
    // The user has selected/unselected a calendar in Prefs.
    // Update the kSelectedCalendars array in NSUserDefaults.
    NSMutableArray *selectedCalendars = [NSMutableArray new];
    [self.sourcesAndCalendars enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[CalendarInfo class]] &&
            [(CalendarInfo *)obj selected]) {
            [selectedCalendars addObject:[(CalendarInfo *)obj identifier]];
        }
    }];
    [[NSUserDefaults standardUserDefaults] setObject:selectedCalendars forKey:kSelectedCalendars];
}

#pragma mark -
#pragma mark Events


#pragma mark -
#pragma mark Store changed notification

- (void)storeChanged:(NSNotification *)note
{
    // The system told us the event store has changed so
    // we have to refetch everything.
    
    // Remove stored events
    [self fetchSourcesAndCalendars];
    // Fetch events
}

@end
