//
//  EventQuickEntryKeywords.h
//  Itsycal
//
//  Created by Scott Goci on 7/27/26.
//

#import <Foundation/Foundation.h>
#import "EventQuickEntryLanguagePack.h"

NS_ASSUME_NONNULL_BEGIN

// The word/phrase lists that drive EventQuickEntryKeywordLanguagePack.
// A new keyword-based language pack only needs to supply one of these —
// no new matching logic. All arrays are case-insensitive whole-word/phrase
// matches; NSDataDetector's own date/time recognition (locale-aware,
// not configured here) still does the heavy lifting for the date itself.
@interface EventQuickEntryKeywords : NSObject

// BCP-47-ish language code, e.g. "en", "es". Used to localize the date
// formatter used for tooltip display text.
@property (nonatomic, copy) NSString *languageCode;

// The word before a duration phrase, e.g. "for" (en) / "durante" (es).
@property (nonatomic, copy) NSString *durationPrefixWord;

// The idiom for exactly 30 minutes, e.g. "half an hour" (en) / "media hora" (es).
@property (nonatomic, copy) NSString *halfHourPhrase;

// Idioms for exactly one hour, e.g. @[@"a hour", @"an hour"] (en) / @[@"una hora"] (es).
@property (nonatomic, copy) NSArray<NSString *> *oneHourPhrases;

// Words for "hours", e.g. @[@"hours", @"hour", @"hrs", @"hr"] (en) / @[@"horas", @"hora"] (es).
// Order matters beyond matching: index 0 is used as the plural display
// word and index 1 as the singular ("1 hour" vs "2 hours") when rendering
// a duration span's tooltip text — see -displayValueForDurationMinutes:.
@property (nonatomic, copy) NSArray<NSString *> *hourUnitWords;

// Words for "minutes", e.g. @[@"minutes", @"minute", @"mins", @"min"] (en) / @[@"minutos", @"minuto"] (es).
// Index 0 is used as the display word for any minute count, including
// exactly 1 (e.g. English always renders "1 minutes", never singularizing
// it) — a known simplification carried over unchanged from before this
// class existed, not something introduced here.
@property (nonatomic, copy) NSArray<NSString *> *minuteUnitWords;

// Words introducing a location, e.g. @[@"at", @"in"] (en) / @[@"en", @"a"] (es).
// "@" is always recognized as a location prefix regardless of language.
@property (nonatomic, copy) NSArray<NSString *> *locationPrefixWords;

// Words that can precede a date/time reference without being part of it,
// so NSDataDetector's match (which never includes them) doesn't leave
// them stranded in the title — e.g. @[@"on"] (en) / @[@"el", @"la", @"esta", @"este"] (es).
@property (nonatomic, copy) NSArray<NSString *> *danglingPrefixWords;

// Meal words NSDataDetector may fold into its own date match as an
// implicit time-of-day reference, e.g. @[@"lunch", @"breakfast", @"dinner", @"brunch"] (en).
@property (nonatomic, copy) NSArray<NSString *> *mealWords;

// Non-numeric words that indicate NSDataDetector resolved an explicit
// time (beyond the universal digit+am/pm and digit:digit patterns, which
// are always recognized), e.g. @[@"noon", @"midnight", @"morning", @"afternoon", @"evening"] (en).
@property (nonatomic, copy) NSArray<NSString *> *explicitTimeWords;

// Phrases for each recurrence frequency. Keys are fixed and match
// EventQuickEntryRecurrence's non-None cases: "everyDay", "everyWeek",
// "every2Weeks", "everyMonth", "everyYear".
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *recurrencePhrasesByFrequencyKey;

// Display label for each recurrence frequency, same keys as above — must
// match the corresponding item title in EventViewController's _repPopup.
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *recurrenceLabelsByFrequencyKey;

// Category labels shown in span tooltips, e.g. "Date"/"Duration"/
// "Location"/"Repeat" (en) or "Fecha"/"Duración"/"Ubicación"/"Repetir" (es).
@property (nonatomic, copy) NSString *dateSpanLabel;
@property (nonatomic, copy) NSString *durationSpanLabel;
@property (nonatomic, copy) NSString *locationSpanLabel;
@property (nonatomic, copy) NSString *repeatSpanLabel;

// Word joining a date and time in the date span's tooltip display value,
// e.g. "Friday, January 2 <connector> 3:00 PM" — "at" (en) / "a las" (es).
@property (nonatomic, copy) NSString *dateTimeConnector;

// Relative-period phrases NSDataDetector doesn't recognize on its own —
// confirmed empirically: it resolves day-of-week-based phrases like "next
// Tuesday" and count-of-days phrases like "in 3 days" or "tomorrow" just
// fine, but has no support at all for bare relative-period phrases like
// "next week", "next month", or "next year", even standalone. These
// properties drive a small custom detector that runs before NSDataDetector
// to cover that gap, recognizing three forms per unit (week/month/year):
// "next <unit>", "<relativePeriodPrefixWord> N <unit>s" (e.g. "in 2
// weeks"), and "N <unit>s <relativePeriodFromNowSuffix>" (e.g. "2 weeks
// from now"). N may be a digit string or one of numberWords. Leaving any
// property empty simply disables the phrase(s) it drives — see
// -relativePeriodSpanInMasked:original:result:calendar:.
@property (nonatomic, copy) NSString *nextWeekPhrase;   // e.g. "next week" (en)
@property (nonatomic, copy) NSString *nextMonthPhrase;  // e.g. "next month" (en)
@property (nonatomic, copy) NSString *nextYearPhrase;   // e.g. "next year" (en)
@property (nonatomic, copy) NSString *relativePeriodPrefixWord;    // e.g. "in" (en) — shared across all three units
@property (nonatomic, copy) NSString *relativePeriodFromNowSuffix; // e.g. "from now" (en) — shared across all three units
@property (nonatomic, copy) NSArray<NSString *> *weekUnitWords;  // e.g. @[@"weeks", @"week"] (en)
@property (nonatomic, copy) NSArray<NSString *> *monthUnitWords; // e.g. @[@"months", @"month"] (en)
@property (nonatomic, copy) NSArray<NSString *> *yearUnitWords;  // e.g. @[@"years", @"year"] (en)

// Spelled-out counts, ordered 1..N by position — e.g. @[@"one", @"two", ...]
// so index 0 means 1, index 1 means 2, etc. Digit strings ("2") are always
// recognized regardless of this list; this only adds word forms on top.
@property (nonatomic, copy) NSArray<NSString *> *numberWords;

// Example phrase shown as the quick-entry field's placeholder text.
@property (nonatomic, copy) NSString *placeholderExample;

// Loads keywords from a .strings file on disk with the shape shown by
// Base.lproj/EventQuickEntryKeywords.strings / es.lproj/EventQuickEntryKeywords.strings
// — the same flat "key" = "value"; format as Localizable.strings. Array-
// valued properties are a single pipe-delimited entry ("word1|word2");
// the two recurrence dictionaries are flattened into "recurrencePhrases.<key>"
// / "recurrenceLabel.<key>" entries, one per frequency. Returns nil if the
// file is missing or isn't a valid .strings file.
+ (nullable instancetype)keywordsWithContentsOfStringsFileAtPath:(NSString *)path;

// The fixed key order for recurrencePhrasesByFrequencyKey/
// recurrenceLabelsByFrequencyKey — every2Weeks is deliberately checked
// before everyWeek so "every other week"-style phrases aren't shadowed by
// the plain "every week" pattern.
+ (NSArray<NSString *> *)recurrenceFrequencyKeys;

@end

// Generic EventQuickEntryLanguagePack implementation driven entirely by
// an EventQuickEntryKeywords config — the matching *logic* (masked-text
// pipeline, regex shapes) is fixed; only the words are configurable. Every
// keyword-based language uses this same class directly, constructed from
// keywords loaded from that language's .strings file — see
// EventQuickEntryLanguagePackRegistry, which is how you actually get one.
@interface EventQuickEntryKeywordLanguagePack : NSObject <EventQuickEntryLanguagePack>

- (instancetype)initWithKeywords:(EventQuickEntryKeywords *)keywords NS_DESIGNATED_INITIALIZER;

// Shared utility available to any EventQuickEntryLanguagePack implementation
// (not just this base class) for the masked-text technique: replaces
// `range` in `masked` with spaces of the same length, so indices into the
// original string stay valid and later detectors never re-match it.
+ (void)blankRange:(NSRange)range inMasked:(NSMutableString *)masked;

@end

NS_ASSUME_NONNULL_END
