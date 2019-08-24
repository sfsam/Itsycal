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
    return [NSColor colorNamed:@"AgendaDayTextColor"];
}

- (NSColor *)agendaDividerColor {
    return [NSColor colorNamed:@"AgendaDividerColor"];
}

- (NSColor *)agendaDOWTextColor {
    return [self monthTextColor];
}

- (NSColor *)agendaEventDateTextColor {
    return [NSColor colorNamed:@"AgendaEventDateTextColor"];
}

- (NSColor *)agendaEventTextColor {
    return [self monthTextColor];
}

- (NSColor *)agendaHoverColor {
    return [NSColor colorNamed:@"AgendaHoverColor"];
}

- (NSColor *)currentMonthOutlineColor {
    return [NSColor colorNamed:@"CurrentMonthOutlineColor"];
}

- (NSColor *)currentMonthTextColor {
    return [NSColor colorNamed:@"CurrentMonthTextColor"];
}

- (NSColor *)DOWTextColor {
    return [NSColor colorNamed:@"DOWTextColor"];
}

- (NSColor *)highlightedDOWBackgroundColor {
    return [NSColor colorNamed:@"HighlightedDOWBackgroundColor"];
}

- (NSColor *)highlightedDOWTextColor {
    return [NSColor colorNamed:@"HighlightedDOWTextColor"];
}

- (NSColor *)highlightedDOWTextColorAlpha {
    return [NSColor colorNamed:@"HighlightedDOWTextColorAlpha"];
}

- (NSColor *)hoveredCellColor {
    return [NSColor colorNamed:@"HoveredCellColor"];
}

- (NSColor *)mainBackgroundColor {
    return [NSColor colorNamed:@"MainBackgroundColor"];
}

- (NSColor *)monthTextColor {
    return [NSColor colorNamed:@"MonthTextColor"];
}

- (NSColor *)noncurrentMonthTextColor {
    return [NSColor colorNamed:@"NonCurrentMonthTextColor"];
}

- (NSColor *)resizeHandleBackgroundColor {
    return [NSColor colorNamed:@"ResizeHandleBackgroundColor"];
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
    return [NSColor colorNamed:@"WeekTextColor"];
}

- (NSColor *)windowBorderColor {
    return [NSColor colorNamed:@"WindowBorderColor"];
}

@end
