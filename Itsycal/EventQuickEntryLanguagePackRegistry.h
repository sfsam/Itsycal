//
//  EventQuickEntryLanguagePackRegistry.h
//  Itsycal
//
//  Created by Scott Goci on 7/27/26.
//

#import <Foundation/Foundation.h>
#import "EventQuickEntryLanguagePack.h"

NS_ASSUME_NONNULL_BEGIN

@interface EventQuickEntryLanguagePackRegistry : NSObject
// Returns the language pack for a BCP-47-ish language code (e.g. from
// -[NSBundle preferredLocalizations]), or nil if no pack is registered for
// it. A language is "registered" simply by the presence of an
// EventQuickEntryKeywords.strings resource in that language's <code>.lproj
// folder (English lives in Base.lproj, like the rest of the app's
// development-language resources) — the same localized-resource-variant
// mechanism already used for Localizable.strings/MainMenu.xib. Adding a
// new keyword-based language means adding a new .lproj/EventQuickEntryKeywords.strings
// file, not writing or compiling any code. Matches by primary language
// subtag, so "en-US"/"en-GB"/etc. all resolve to the "en" (Base) pack.
+ (nullable id<EventQuickEntryLanguagePack>)packForLanguageCode:(NSString *)languageCode;
@end

NS_ASSUME_NONNULL_END
