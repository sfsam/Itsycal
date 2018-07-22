//
//  Created by Sanjay Madan on 6/12/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "Themer.h"
#import "Itsycal.h"
#import "MoUtils.h"

// NSUserDefaults key
NSString * const kThemePreference = @"ThemePreference";

// Notification names
NSString * const kThemeDidChangeNotification = @"ThemeDidChangeNotification";

typedef enum : NSInteger {
    ThemeLight = 0,
    ThemeDark  = 1
} Theme;

@interface Themer ()

@property (nonatomic) Theme theme;

@end

@implementation Themer

+ (instancetype)shared
{
    static Themer *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[Themer alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _themePreference = [[NSUserDefaults standardUserDefaults] integerForKey:kThemePreference];
        if (_themePreference == ThemePreferenceSystem) {
            _theme = [self systemUsesDarkMode] ? ThemeDark : ThemeLight;
        }
        else if (_themePreference == ThemePreferenceDark) {
            _theme = ThemeDark;
        }
        else {
            _theme = ThemeLight;
        }
        // Watch for appearance changes on 10.14+.
        if (OSVersionIsAtLeast(10, 14, 0)) {
            [NSApp.windows[0] addObserver:self forKeyPath:@"effectiveAppearance" options:NSKeyValueObservingOptionNew context:nil];
        }
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    // Only called from 10.14+.
    if ([keyPath isEqualToString:@"effectiveAppearance"]) {
        if (self.themePreference == ThemePreferenceSystem) {
            self.theme = [self systemUsesDarkMode] ? ThemeDark : ThemeLight;
        }
    }
}

- (BOOL)systemUsesDarkMode
{
    // Only called from 10.14+.
    // Determine appearance based on the main window.
    return ![NSApp.windows[0].effectiveAppearance.name isEqualToString:NSAppearanceNameAqua];
}

- (void)setThemePreference:(ThemePreference)themePref
{
    // Validate themePref.
    // If it's out of range, set it to its minimum value.
    // minThemePref is 0 (System) for macOS 10.14+, else 1 (Light).
    NSInteger minThemePref = OSVersionIsAtLeast(10, 14, 0) ? 0 : 1;
    themePref = (themePref < minThemePref || themePref > 2) ? minThemePref : themePref;

    _themePreference = themePref;
    
    switch (themePref) {
        case ThemePreferenceSystem:
            self.theme = [self systemUsesDarkMode] ? ThemeDark : ThemeLight;
            break;
        case ThemePreferenceDark:
            self.theme = ThemeDark;
            break;
        case ThemePreferenceLight:
        default:
            self.theme = ThemeLight;
    }
}

- (void)setTheme:(Theme)theme
{
    _theme = theme;
    [[NSNotificationCenter defaultCenter] postNotificationName:kThemeDidChangeNotification object:nil];    
}

- (NSColor *)mainBackgroundColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.15 alpha:1]
    : [NSColor whiteColor];
}

- (NSColor *)windowBorderColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.6 alpha:0.4]
    : [NSColor colorWithWhite:0.4 alpha:0.4];
}

- (NSColor *)monthTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.83 alpha:1]
    : [NSColor blackColor];
}

- (NSColor *)DOWTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.8 alpha:1]
    : [NSColor colorWithWhite:0.2 alpha:1];
}

- (NSColor *)highlightedDOWTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithRed:0.95 green:0.5 blue:0.4 alpha:1]
    : [NSColor colorWithRed:0.91 green:0.3 blue:0.1 alpha:1];
}

- (NSColor *)currentMonthOutlineColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.55 alpha:1]
    : [NSColor colorWithWhite:0.77 alpha:1];
}

- (NSColor *)currentMonthTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.77 alpha:1]
    : [self DOWTextColor];
}

- (NSColor *)noncurrentMonthTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:1 alpha:0.4]
    : [NSColor colorWithWhite:0 alpha:0.33];
}

- (NSColor *)weekTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.55 alpha:1]
    : [NSColor grayColor];
}

- (NSColor *)todayCellColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithRed:0.36 green:0.54 blue:0.9 alpha:1]
    : [NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1];
}

- (NSColor *)hoveredCellColor
{
    return [self currentMonthOutlineColor];
}

- (NSColor *)selectedCellColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.75 alpha:1]
    : [NSColor colorWithWhite:0.55 alpha:1];
}

- (NSColor *)resizeHandleForegroundColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.7 alpha:1]
    : [NSColor colorWithWhite:0.4 alpha:1];
}

- (NSColor *)resizeHandleBackgroundColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.22 alpha:1]
    : [NSColor colorWithWhite:0.95 alpha:1];
}

- (NSColor *)agendaDividerColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.27 alpha:1]
    : [NSColor colorWithWhite:0.86 alpha:1];
}

- (NSColor *)agendaHoverColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.25 alpha:1]
    : [NSColor colorWithRed:0.94 green:0.95 blue:0.98 alpha:1];
}

- (NSColor *)agendaDayTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.5 alpha:1]
    : [NSColor colorWithWhite:0.5 alpha:1];
}

- (NSColor *)agendaDOWTextColor
{
    return [self monthTextColor];
}

- (NSColor *)agendaEventTextColor
{
    return [self monthTextColor];
}

- (NSColor *)agendaEventDateTextColor
{
    return self.theme != ThemeLight
    ? [NSColor colorWithWhite:0.55 alpha:1]
    : [NSColor colorWithWhite:0.55 alpha:1];
}

- (NSColor *)tooltipBackgroundColor
{
    return [self mainBackgroundColor];
}

@end
