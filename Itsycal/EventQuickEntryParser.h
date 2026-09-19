//
//  EventQuickEntryParser.h
//  Itsycal
//
//  Created by Scott Goci on 7/27/26.
//

#import <Foundation/Foundation.h>
#import "EventQuickEntryLanguagePack.h"

NS_ASSUME_NONNULL_BEGIN

// Values match the index of the corresponding item in EventViewController's
// _repPopup (EventViewController.m): 0 = None, 1 = Every Day, 2 = Every Week,
// 3 = Every 2 Weeks, 4 = Every Month, 5 = Every Year.
typedef NS_ENUM(NSInteger, EventQuickEntryRecurrence) {
    EventQuickEntryRecurrenceNone        = 0,
    EventQuickEntryRecurrenceEveryDay    = 1,
    EventQuickEntryRecurrenceEveryWeek   = 2,
    EventQuickEntryRecurrenceEvery2Weeks = 3,
    EventQuickEntryRecurrenceEveryMonth  = 4,
    EventQuickEntryRecurrenceEveryYear   = 5,
};

// A stable, non-localized identifier for what kind of thing a span
// represents — distinct from `label`, which is display text. Consumers
// that need to branch on span type (e.g. picking a highlight color)
// should switch on `kind`, not compare `label` strings, since `label`
// is the one part of a span meant to vary by language pack.
typedef NS_ENUM(NSInteger, EventQuickEntrySpanKind) {
    EventQuickEntrySpanKindDate,
    EventQuickEntrySpanKindDuration,
    EventQuickEntrySpanKindLocation,
    EventQuickEntrySpanKindRepeat,
};

@interface EventQuickEntrySpan : NSObject
@property (nonatomic) NSRange range; // into the original input string
@property (nonatomic) EventQuickEntrySpanKind kind;
@property (nonatomic, copy) NSString *label;        // "Date", "Duration", "Location", "Repeat"
@property (nonatomic, copy) NSString *displayValue;  // human-readable interpreted value
@end

@interface EventQuickEntryResult : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, nullable) NSDate *date;
@property (nonatomic) BOOL hasExplicitTime;
@property (nonatomic) NSInteger durationMinutes; // 0 == not detected
@property (nonatomic, copy, nullable) NSString *location;
@property (nonatomic) EventQuickEntryRecurrence recurrence;
@property (nonatomic, copy) NSArray<EventQuickEntrySpan *> *recognizedSpans;
@end

@interface EventQuickEntryParser : NSObject
// Convenience initializer using the English language pack.
- (instancetype)init;
- (instancetype)initWithLanguagePack:(id<EventQuickEntryLanguagePack>)languagePack NS_DESIGNATED_INITIALIZER;
// Parses free-form text into title/date/duration/location/recurrence.
// `calendar` is used for all date component arithmetic.
- (EventQuickEntryResult *)parse:(NSString *)text calendar:(NSCalendar *)calendar;
@end

NS_ASSUME_NONNULL_END
