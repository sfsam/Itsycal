//
//  ContactEventManager.m
//  Itsycal
//
//  Created by Mr.Buch on 2/15/26.
//  Manages contact dates (birthdays, anniversaries, etc.) as calendar events
//

#import "ContactEventManager.h"
#import "EventCenter.h"
#import "MoDate.h"
#import <Contacts/Contacts.h>
#import <AppKit/AppKit.h>

@implementation ContactEventManager {
    CNContactStore *_contactStore;
    NSCalendar *_calendar;
}

- (instancetype)initWithCalendar:(NSCalendar *)calendar {
    self = [super init];
    if (self) {
        _calendar = calendar;
        _contactStore = [[CNContactStore alloc] init];
    }
    return self;
}

- (BOOL)contactsAccessGranted {
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    return status == CNAuthorizationStatusAuthorized;
}

- (void)requestContactsAccessWithCompletion:(void (^)(BOOL granted))completion {
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    
    if (status == CNAuthorizationStatusAuthorized) {
        if (completion) completion(YES);
        return;
    }
    
    if (status == CNAuthorizationStatusNotDetermined) {
        NSLog(@"[ContactEventManager] Requesting contacts access...");
        [_contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(granted);
                });
            }
        }];
    } else {
        NSLog(@"[ContactEventManager] Contacts access denied or restricted (status: %ld)", (long)status);
        if (completion) completion(NO);
    }
}

- (void)contactEventsFromDate:(MoDate)startDate
                        toDate:(MoDate)endDate
                    completion:(void (^)(NSDictionary<NSDate *, NSArray<EventInfo *> *> *events))completion {
    if (![self contactsAccessGranted]) {
        NSLog(@"[ContactEventManager] Contacts access NOT granted. Cannot fetch events.");
        if (completion) {
            completion(@{});
        }
        return;
    }
    
    // Perform the synchronous fetch on a utility queue to match EventCenter's QoS
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *events = [self _fetchContactEventsFromDate:startDate toDate:endDate];
        if (completion) {
            completion(events);
        }
    });
}

- (NSDictionary<NSDate *, NSArray<EventInfo *> *> *)_fetchContactEventsFromDate:(MoDate)startDate
                                                                          toDate:(MoDate)endDate {
    NSLog(@"[ContactEventManager] Contacts access granted. Fetching contact dates...");
    
    NSMutableDictionary<NSDate *, NSMutableArray<EventInfo *> *> *eventsForDate = [NSMutableDictionary dictionary];
    
    // Get the years we need to fetch for
    NSDateComponents *startComponents = [_calendar components:NSCalendarUnitYear fromDate:MakeNSDateWithDate(startDate, _calendar)];
    NSDateComponents *endComponents = [_calendar components:NSCalendarUnitYear fromDate:MakeNSDateWithDate(endDate, _calendar)];
    
    NSInteger startYear = startComponents.year;
    NSInteger endYear = endComponents.year;
    
    // Fetch contacts and process their dates
    NSError *error = nil;
    NSArray *keysToFetch = @[
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactNicknameKey,
        CNContactBirthdayKey,
        CNContactDatesKey,
        CNContactImageDataAvailableKey
    ];
    
    CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
    
    __block NSInteger contactCount = 0;
    
    // Enumerate contacts - this is synchronous but we're on an appropriate QoS queue now
    [_contactStore enumerateContactsWithFetchRequest:request error:&error usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
        contactCount++;
        NSString *displayName = [self displayNameForContact:contact];
        
        // Process birthday
        if (contact.birthday) {
            [self addEventsForDateComponents:contact.birthday
                                        name:displayName
                                       label:@"Birthday"
                                       emoji:@"🎂"
                                   startYear:startYear
                                     endYear:endYear
                                  startMoDate:startDate
                                    endMoDate:endDate
                               eventsForDate:eventsForDate];
        }
        
        // Process anniversaries and other dates
        for (CNLabeledValue<NSDateComponents *> *labeledDate in contact.dates) {
            NSString *label = [self labelStringForLabel:labeledDate.label];
            NSString *emoji = [self emojiForLabel:labeledDate.label];
            
            [self addEventsForDateComponents:labeledDate.value
                                        name:displayName
                                       label:label
                                       emoji:emoji
                                   startYear:startYear
                                     endYear:endYear
                                  startMoDate:startDate
                                    endMoDate:endDate
                               eventsForDate:eventsForDate];
        }
    }];
    
    if (error) {
        NSLog(@"[ContactEventManager] Error fetching contacts: %@", error);
        return @{};
    }
    
    
    return eventsForDate;
}

- (void)addEventsForDateComponents:(NSDateComponents *)dateComponents
                              name:(NSString *)name
                             label:(NSString *)label
                             emoji:(NSString *)emoji
                         startYear:(NSInteger)startYear
                           endYear:(NSInteger)endYear
                        startMoDate:(MoDate)startMoDate
                          endMoDate:(MoDate)endMoDate
                     eventsForDate:(NSMutableDictionary<NSDate *, NSMutableArray<EventInfo *> *> *)eventsForDate {
    
    if (!dateComponents || !dateComponents.month || !dateComponents.day) {
        return; // Invalid date components
    }
    
    // Create events for each year in the range
    for (NSInteger year = startYear; year <= endYear; year++) {
        NSDateComponents *eventComponents = [[NSDateComponents alloc] init];
        eventComponents.year = year;
        eventComponents.month = dateComponents.month;
        eventComponents.day = dateComponents.day;
        eventComponents.hour = 0;
        eventComponents.minute = 0;
        eventComponents.second = 0;
        
        NSDate *eventDate = [_calendar dateFromComponents:eventComponents];
        if (!eventDate) continue;
        
        // Check if this date falls within our range
        MoDate eventMoDate = MakeDateWithNSDate(eventDate, _calendar);
        if (eventMoDate.julian < startMoDate.julian || eventMoDate.julian > endMoDate.julian) {
            continue;
        }
        
        // Calculate age/years if original year is known
        NSString *title;
        if (dateComponents.year && dateComponents.year != NSDateComponentUndefined) {
            NSInteger yearsCount = year - dateComponents.year;
            if (yearsCount > 0) {
                title = [NSString stringWithFormat:@"%@ %@'s %@ (%ld)", emoji, name, label, (long)yearsCount];
            } else {
                title = [NSString stringWithFormat:@"%@ %@'s %@", emoji, name, label];
            }
        } else {
            title = [NSString stringWithFormat:@"%@ %@'s %@", emoji, name, label];
        }
        
        // Create EventInfo for contact event
        EventInfo *info = [[EventInfo alloc] init];
        info.event = nil; // No actual calendar event
        info.isContactEvent = YES;
        info.contactEventTitle = title;
        info.contactEventDate = eventDate;
        info.contactEventColor = [self colorForLabel:label]; // Use a distinct color for contact events
        info.isStartDate = YES;
        info.isEndDate = YES;
        info.isAllDay = YES;
        
        // Add to dictionary
        NSDate *startOfDay = [_calendar startOfDayForDate:eventDate];
        if (!eventsForDate[startOfDay]) {
            eventsForDate[startOfDay] = [NSMutableArray array];
        }
        [eventsForDate[startOfDay] addObject:info];
    }
}

- (NSString *)displayNameForContact:(CNContact *)contact {
    if (contact.givenName.length > 0 && contact.familyName.length > 0) {
        return [NSString stringWithFormat:@"%@ %@", contact.givenName, contact.familyName];
    } else if (contact.givenName.length > 0) {
        return contact.givenName;
    } else if (contact.familyName.length > 0) {
        return contact.familyName;
    } else if (contact.nickname.length > 0) {
        return contact.nickname;
    }
    return @"Unknown Contact";
}

- (NSString *)labelStringForLabel:(NSString *)label {
    if ([label isEqualToString:CNLabelDateAnniversary]) {
        return @"Anniversary";
    } else if ([label isEqualToString:CNLabelHome]) {
        return @"Home Date";
    } else if ([label isEqualToString:CNLabelWork]) {
        return @"Work Date";
    } else if ([label isEqualToString:CNLabelOther]) {
        return @"Other Date";
    }
    
    // Try to localize the label
    NSString *localizedLabel = [CNLabeledValue localizedStringForLabel:label];
    if (localizedLabel && ![localizedLabel isEqualToString:label]) {
        return localizedLabel;
    }
    
    // Remove prefix if present (e.g., "_$!<Anniversary>!$_" -> "Anniversary")
    if ([label hasPrefix:@"_$!<"] && [label hasSuffix:@">!$_"]) {
        return [label substringWithRange:NSMakeRange(4, label.length - 8)];
    }
    
    return label;
}

- (NSString *)emojiForLabel:(NSString *)label {
    if ([label isEqualToString:CNLabelDateAnniversary]) {
        return @"💍";
    } else if ([label containsString:@"Wedding"]) {
        return @"💒";
    } else if ([label containsString:@"Engagement"]) {
        return @"💍";
    } else if ([label containsString:@"Relationship"]) {
        return @"❤️";
    }
    return @"📅";
}

- (NSColor *)colorForLabel:(NSString *)label {
    // Use a purple/magenta color for contact events to distinguish from calendar events
    return [NSColor colorWithRed:0.8 green:0.4 blue:0.8 alpha:1.0];
}

@end
