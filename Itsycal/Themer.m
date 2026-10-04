//
//  Created by Sanjay Madan on 6/12/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "Themer.h"
#import "Itsycal.h"
#import "MoUtils.h"

// NSUserDefaults key
NSString * const kThemePreference = @"ThemePreference";

@implementation Themer

Themer *Theme = nil;

+ (instancetype)shared
{
    static Themer *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[Themer alloc] init];
        Theme = shared;
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _themePreference = [[NSUserDefaults standardUserDefaults] integerForKey:kThemePreference];
        [self adjustAppAppearanceForThemePreference];
    }
    return self;
}

- (void)setThemePreference:(ThemePreference)themePref {
    // Validate themePref before setting ivar.
    _themePreference = (themePref < 0 || themePref > 2) ? 0 : themePref;
    [self adjustAppAppearanceForThemePreference];
}

- (void)adjustAppAppearanceForThemePreference {
    switch (_themePreference) {
        case ThemePreferenceSystem:
            NSApp.appearance = nil;
            break;
        case ThemePreferenceDark:
            NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
            break;
        case ThemePreferenceLight:
        default:
            NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    }
}

- (NSColor *)agendaDayTextColor {
    return NSColor.secondaryLabelColor;
}

- (NSColor *)agendaDividerColor {
    return NSColor.separatorColor;
}

- (NSColor *)agendaDOWTextColor {
    return [self monthTextColor];
}

- (NSColor *)agendaEventDateTextColor {
    return NSColor.secondaryLabelColor;
}

- (NSColor *)agendaEventTextColor {
    return [self monthTextColor];
}

- (NSColor *)agendaHoverColor {
    return [self highlightedDOWBackgroundColor];
}

- (NSColor *)currentMonthOutlineColor {
    return [self monthTextColor];
}

- (NSColor *)currentMonthTextColor {
    return NSColor.labelColor;
}

- (NSColor *)DOWTextColor {
    return NSColor.labelColor;
}

- (NSColor *)highlightedDOWBackgroundColor {
    return [NSColor colorNamed:@"HighlightedDOWBackgroundColor"];
}

- (NSColor *)highlightedDOWTextColor {
    return NSColor.secondaryLabelColor;
}

- (NSColor *)hoveredCellColor {
    return NSColor.tertiaryLabelColor;
}

- (NSColor *)mainBackgroundColor {
    return [NSColor colorNamed:@"MainBackgroundColor"];
}

- (NSColor *)monthTextColor {
    return NSColor.labelColor;
}

- (NSColor *)noncurrentMonthTextColor {
    return NSColor.tertiaryLabelColor;
}

- (NSColor *)pendingBackgroundColor {
    return [NSColor colorNamed:@"PendingBackgroundColor"];
}

- (NSColor *)resizeHandleBackgroundColor {
    return [self highlightedDOWBackgroundColor];
}

- (NSColor *)resizeHandleForegroundColor {
    return [NSColor colorNamed:@"ResizeHandleForegroundColor"];
}

- (NSColor *)selectedCellColor {
    return [self currentMonthOutlineColor];
}

- (NSColor *)todayCellColor {
    return [NSColor colorNamed:@"TodayCellColor"];
}

- (NSColor *)tooltipBackgroundColor {
    return [self mainBackgroundColor];
}

- (NSColor *)weekTextColor {
    return NSColor.secondaryLabelColor;
}

@end
