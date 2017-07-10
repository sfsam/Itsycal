//
//  Created by Sanjay Madan on 6/12/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "Themer.h"
#import "Itsycal.h"

// NSUserDefaults key
NSString * const kThemeIndex = @"ThemeIndex";

// Notification names
NSString * const kThemeDidChangeNotification = @"ThemeDidChangeNotification";

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
        _themeIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kThemeIndex];
    }
    return self;
}

- (void)setThemeIndex:(ThemeIndex)themeIndex
{
    if (_themeIndex == themeIndex) return;
    _themeIndex = themeIndex;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kThemeDidChangeNotification object:nil];    
}

- (NSColor *)mainBackgroundColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.15 alpha:1]
    : [NSColor whiteColor];
}

- (NSColor *)windowBorderColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.0 alpha:0.6]
    : [NSColor colorWithWhite:0.4 alpha:0.4];
}

- (NSColor *)monthTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.86 alpha:1]
    : [NSColor blackColor];
}

- (NSColor *)DOWTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.8 alpha:1]
    : [NSColor colorWithWhite:0.25 alpha:1];
}

- (NSColor *)highlightedDOWTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithRed:0.95 green:0.5 blue:0.4 alpha:1]
    : [NSColor colorWithRed:0.91 green:0.3 blue:0.1 alpha:1];
}

- (NSColor *)currentMonthOutlineColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.66 alpha:1]
    : [NSColor colorWithWhite:0.73 alpha:1];
}

- (NSColor *)currentMonthFillColor
{
    return self.themeIndex != 0
    ? [NSColor clearColor]
    : [NSColor clearColor];
}

- (NSColor *)currentMonthTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.77 alpha:1]
    : [self DOWTextColor];
}

- (NSColor *)noncurrentMonthTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:1 alpha:0.4]
    : [NSColor colorWithWhite:0 alpha:0.33];
}

- (NSColor *)weekTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.55 alpha:1]
    : [NSColor grayColor];
}

- (NSColor *)todayCellColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1]
    : [NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1];
}

- (NSColor *)hoveredCellColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.55 alpha:1]
    : [NSColor colorWithRed:0.2 green:0.2 blue:0.3 alpha:0.2];
}

- (NSColor *)selectedCellColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.8 alpha:1]
    : [NSColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:0.7];
}

- (NSColor *)resizeHandleForegroundColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.7 alpha:1]
    : [NSColor colorWithWhite:0.4 alpha:1];
}

- (NSColor *)resizeHandleBackgroundColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.17 alpha:1]
    : [NSColor colorWithWhite:0.98 alpha:1];
}

- (NSColor *)agendaDividerColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.22 alpha:1]
    : [NSColor colorWithWhite:0.9 alpha:1];
}

- (NSColor *)agendaHoverColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.25 alpha:1]
    : [NSColor colorWithRed:0.94 green:0.95 blue:0.98 alpha:1];
}

- (NSColor *)agendaDayTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.86 alpha:1]
    : [NSColor blackColor];
}

- (NSColor *)agendaDOWTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.7 alpha:1]
    : [NSColor colorWithWhite:0.4 alpha:1];
}

- (NSColor *)agendaEventTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.8 alpha:1]
    : [NSColor colorWithWhite:0.1 alpha:1];
}

- (NSColor *)agendaEventDateTextColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.5 alpha:1]
    : [NSColor colorWithWhite:0.5 alpha:1];
}

- (NSColor *)tooltipBackgroundColor
{
    return self.themeIndex != 0
    ? [NSColor colorWithWhite:0.2 alpha:1]
    : [self mainBackgroundColor];
}

@end
