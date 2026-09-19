//
//  EventQuickEntryLanguagePackRegistry.m
//  Itsycal
//
//  Created by Scott Goci on 7/27/26.
//

#import "EventQuickEntryLanguagePackRegistry.h"
#import "EventQuickEntryKeywords.h"

@implementation EventQuickEntryLanguagePackRegistry

+ (nullable id<EventQuickEntryLanguagePack>)packForLanguageCode:(NSString *)languageCode
{
    NSBundle *bundle = [NSBundle bundleForClass:[EventQuickEntryKeywords class]];
    NSString *primaryCode = [languageCode componentsSeparatedByString:@"-"].firstObject ?: languageCode;

    NSURL *url = [bundle URLForResource:@"EventQuickEntryKeywords" withExtension:@"strings" subdirectory:nil localization:primaryCode];
    if (!url && [primaryCode isEqualToString:@"en"]) {
        // English keywords live in Base.lproj — the project's development-
        // language folder — like the rest of the app's base-language
        // resources; there's no separate en.lproj.
        url = [bundle URLForResource:@"EventQuickEntryKeywords" withExtension:@"strings" subdirectory:nil localization:@"Base"];
    }
    if (!url) return nil;

    EventQuickEntryKeywords *keywords = [EventQuickEntryKeywords keywordsWithContentsOfStringsFileAtPath:url.path];
    if (!keywords) return nil;

    return [[EventQuickEntryKeywordLanguagePack alloc] initWithKeywords:keywords];
}

@end
