//
//  Created by Sanjay Madan on 6/12/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "Themer.h"
#import "Itsycal.h"
#import "MoUtils.h"

// NSUserDefaults key
NSString * const kThemePreference = @"ThemePreference";

// Returns a color that resolves to light in Light Mode
// and dark in Dark Mode.
static NSColor *LightDarkColor(NSColor *light, NSColor *dark)
{
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
        BOOL isDark = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] == NSAppearanceNameDarkAqua;
        return isDark ? dark : light;
    }];
}

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
    return LightDarkColor(NSColor.labelColor, NSColor.secondaryLabelColor);
}

- (NSColor *)currentMonthTextColor {
    return NSColor.labelColor;
}

- (NSColor *)DOWTextColor {
    return NSColor.labelColor;
}

- (NSColor *)highlightedDOWBackgroundColor {
    return NSColor.secondarySystemFillColor;
}

- (NSColor *)highlightedDOWTextColor {
    return NSColor.secondaryLabelColor;
}

- (NSColor *)hoveredCellColor {
    return NSColor.tertiaryLabelColor;
}

- (NSColor *)mainBackgroundColor {
    // windowBackgroundColor is white in Light Mode. In Dark
    // Mode, use a gray halfway between windowBackgroundColor
    // (0.118) and underPageBackgroundColor (0.157).
    return LightDarkColor(NSColor.windowBackgroundColor, [NSColor colorWithWhite:0.137 alpha:1]);
}

- (NSColor *)monthTextColor {
    return NSColor.labelColor;
}

- (NSColor *)noncurrentMonthTextColor {
    return NSColor.tertiaryLabelColor;
}

- (NSColor *)pendingBackgroundColor {
    return NSColor.secondarySystemFillColor;
}

- (NSColor *)resizeHandleBackgroundColor {
    return [self highlightedDOWBackgroundColor];
}

- (NSColor *)resizeHandleForegroundColor {
    return NSColor.secondaryLabelColor;
}

- (NSColor *)selectedCellColor {
    return [self currentMonthOutlineColor];
}

- (NSColor *)todayCellColor {
    return NSColor.systemBlueColor;
}

- (NSColor *)tooltipBackgroundColor {
    return [self mainBackgroundColor];
}

- (NSColor *)weekTextColor {
    return NSColor.secondaryLabelColor;
}

@end
