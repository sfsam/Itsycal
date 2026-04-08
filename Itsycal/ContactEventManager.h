//
//  ContactEventManager.h
//  Itsycal
//
//  Created by Mr.Buch on 2/15/26.
//  Manages contact dates (birthdays, anniversaries, etc.) as calendar events
//

#import <Foundation/Foundation.h>
#import <Contacts/Contacts.h>
#import "MoDate.h"

@class EventInfo;

NS_ASSUME_NONNULL_BEGIN

@interface ContactEventManager : NSObject

// Did the user grant contacts access?
@property (nonatomic, readonly) BOOL contactsAccessGranted;

- (instancetype)initWithCalendar:(NSCalendar *)calendar;

// Request access to contacts
- (void)requestContactsAccessWithCompletion:(void (^)(BOOL granted))completion;

// Fetch contact dates for a date range and return as EventInfo objects via completion handler
// Completion handler receives a dictionary mapping NSDate -> NSArray<EventInfo *>
// This method is asynchronous and performs work on a background queue
- (void)contactEventsFromDate:(MoDate)startDate 
                        toDate:(MoDate)endDate
                    completion:(void (^)(NSDictionary<NSDate *, NSArray<EventInfo *> *> *events))completion;

@end

NS_ASSUME_NONNULL_END
