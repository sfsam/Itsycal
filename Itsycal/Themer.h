//
//  Created by Sanjay Madan on 6/12/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// NSUserDefaults key
extern NSString * const kThemePreference;

typedef enum : NSInteger {
    ThemePreferenceSystem = 0,
    ThemePreferenceLight = 1,
    ThemePreferenceDark  = 2
} ThemePreference;

@interface Themer : NSObject

// Global constant for shared controller instance (like NSApp).
extern Themer *Theme;

@property (nonatomic) ThemePreference themePreference;
@property (nonatomic, readonly) NSColor *agendaDayTextColor;
@property (nonatomic, readonly) NSColor *agendaDividerColor;
@property (nonatomic, readonly) NSColor *agendaDOWTextColor;
@property (nonatomic, readonly) NSColor *agendaEventDateTextColor;
@property (nonatomic, readonly) NSColor *agendaEventTextColor;
@property (nonatomic, readonly) NSColor *agendaHoverColor;
@property (nonatomic, readonly) NSColor *currentMonthOutlineColor;
@property (nonatomic, readonly) NSColor *currentMonthTextColor;
@property (nonatomic, readonly) NSColor *DOWTextColor;
@property (nonatomic, readonly) NSColor *highlightedDOWBackgroundColor;
@property (nonatomic, readonly) NSColor *highlightedDOWTextColor;
@property (nonatomic, readonly) NSColor *hoveredCellColor;
@property (nonatomic, readonly) NSColor *mainBackgroundColor;
@property (nonatomic, readonly) NSColor *monthTextColor;
@property (nonatomic, readonly) NSColor *noncurrentMonthTextColor;
@property (nonatomic, readonly) NSColor *resizeHandleBackgroundColor;
@property (nonatomic, readonly) NSColor *resizeHandleForegroundColor;
@property (nonatomic, readonly) NSColor *selectedCellColor;
@property (nonatomic, readonly) NSColor *todayCellColor;
@property (nonatomic, readonly) NSColor *tooltipBackgroundColor;
@property (nonatomic, readonly) NSColor *weekTextColor;
@property (nonatomic, readonly) NSColor *windowBorderColor;

+ (instancetype)shared;

@end
