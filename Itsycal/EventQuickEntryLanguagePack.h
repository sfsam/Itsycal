//
//  EventQuickEntryLanguagePack.h
//  Itsycal
//
//  Created by Scott Goci on 7/27/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class EventQuickEntrySpan;
@class EventQuickEntryResult;

// Implement this to add a new language. Each method receives the same
// "masked text" pipeline EventQuickEntryParser already uses: recognized
// ranges are blanked out (replaced with equal-length spaces) as each
// detector runs, so later detectors never re-match text an earlier one
// already claimed, and returned ranges stay valid throughout. A detector
// that finds nothing must return nil, not a zero-length span — every
// field this protocol can set (result.date, result.durationMinutes, etc.)
// is only applied by callers when a value was actually found.
//
// Most languages only need different *words*, not different matching
// logic — see EventQuickEntryKeywordLanguagePack, a generic implementation
// of this protocol driven by an EventQuickEntryKeywords config, which is
// almost certainly what you want. Implement this protocol directly only
// if your language's grammar doesn't fit that shape (e.g. no equivalent
// of English-style prepositions for location/time).
@protocol EventQuickEntryLanguagePack <NSObject>
// Example phrase shown as the quick-entry field's placeholder text, e.g.
// "Meeting with Bob for 30 min this Friday" (en).
@property (nonatomic, readonly, copy) NSString *placeholderExample;
- (nullable EventQuickEntrySpan *)dateSpanInMasked:(NSMutableString *)masked original:(NSString *)original result:(EventQuickEntryResult *)result calendar:(NSCalendar *)calendar;
- (nullable EventQuickEntrySpan *)durationSpanInMasked:(NSMutableString *)masked result:(EventQuickEntryResult *)result;
- (nullable EventQuickEntrySpan *)locationSpanInMasked:(NSMutableString *)masked original:(NSString *)original result:(EventQuickEntryResult *)result;
- (nullable EventQuickEntrySpan *)recurrenceSpanInMasked:(NSMutableString *)masked result:(EventQuickEntryResult *)result;
@end

NS_ASSUME_NONNULL_END
