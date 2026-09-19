//
//  EventQuickEntryParser.m
//  Itsycal
//
//  Created by Scott Goci on 7/27/26.
//

#import "EventQuickEntryParser.h"
#import "EventQuickEntryLanguagePackRegistry.h"

@implementation EventQuickEntrySpan @end

@implementation EventQuickEntryResult

- (instancetype)init
{
    self = [super init];
    if (self) {
        _title = @"";
        _date = nil;
        _hasExplicitTime = NO;
        _durationMinutes = 0;
        _location = nil;
        _recurrence = EventQuickEntryRecurrenceNone;
        _recognizedSpans = @[];
    }
    return self;
}

@end

@implementation EventQuickEntryParser
{
    id<EventQuickEntryLanguagePack> _languagePack;
}

- (instancetype)init
{
    return [self initWithLanguagePack:[EventQuickEntryLanguagePackRegistry packForLanguageCode:@"en"]];
}

- (instancetype)initWithLanguagePack:(id<EventQuickEntryLanguagePack>)languagePack
{
    self = [super init];
    if (self) {
        _languagePack = languagePack;
    }
    return self;
}

- (EventQuickEntryResult *)parse:(NSString *)text calendar:(NSCalendar *)calendar
{
    EventQuickEntryResult *result = [EventQuickEntryResult new];
    NSString *original = text ?: @"";
    NSMutableString *masked = [original mutableCopy];
    NSMutableArray<EventQuickEntrySpan *> *recognizedSpans = [NSMutableArray new];

    EventQuickEntrySpan *dateSpan = [_languagePack dateSpanInMasked:masked original:original result:result calendar:calendar];
    if (dateSpan) [recognizedSpans addObject:dateSpan];

    EventQuickEntrySpan *durationSpan = [_languagePack durationSpanInMasked:masked result:result];
    if (durationSpan) [recognizedSpans addObject:durationSpan];

    EventQuickEntrySpan *locationSpan = [_languagePack locationSpanInMasked:masked original:original result:result];
    if (locationSpan) [recognizedSpans addObject:locationSpan];

    EventQuickEntrySpan *recurrenceSpan = [_languagePack recurrenceSpanInMasked:masked result:result];
    if (recurrenceSpan) [recognizedSpans addObject:recurrenceSpan];

    result.title = [[self class] titleFromMaskedText:masked];
    result.recognizedSpans = recognizedSpans;

    return result;
}

+ (NSString *)titleFromMaskedText:(NSString *)masked
{
    NSString *collapsed = [self collapseWhitespace:masked];
    return [collapsed stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)collapseWhitespace:(NSString *)text
{
    static NSRegularExpression *whitespaceRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        whitespaceRegex = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:nil];
    });
    return [whitespaceRegex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@" "];
}

@end
