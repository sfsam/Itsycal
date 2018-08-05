//
//  Created by Sanjay Madan on 6/12/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// NSUserDefaults key
extern NSString * const kThemePreference;

// Notification name
extern NSString * const kThemeDidChangeNotification;

// Convenience macro for notification observer for themable components
#define REGISTER_FOR_THEME_CHANGE [[NSNotificationCenter defaultCenter] \
                                    addObserverForName:kThemeDidChangeNotification \
                                    object:nil queue:[NSOperationQueue mainQueue] \
                                    usingBlock:^(NSNotification *note) { \
                                        [self themeChanged:nil]; \
                                    }];

typedef enum : NSInteger {
    ThemePreferenceSystem = 0,
    ThemePreferenceLight = 1,
    ThemePreferenceDark  = 2
} ThemePreference;

@interface Themer : NSObject

@property (nonatomic) ThemePreference themePreference;

+ (instancetype)shared;

- (NSColor *)mainBackgroundColor;
- (NSColor *)windowBorderColor;
- (NSColor *)monthTextColor;
- (NSColor *)DOWTextColor;
- (NSColor *)highlightedDOWTextColor;
- (NSColor *)currentMonthOutlineColor;
- (NSColor *)currentMonthTextColor;
- (NSColor *)noncurrentMonthTextColor;
- (NSColor *)weekTextColor;
- (NSColor *)todayCellColor;
- (NSColor *)hoveredCellColor;
- (NSColor *)selectedCellColor;
- (NSColor *)resizeHandleForegroundColor;
- (NSColor *)resizeHandleBackgroundColor;
- (NSColor *)agendaDividerColor;
- (NSColor *)agendaHoverColor;
- (NSColor *)agendaDayTextColor;
- (NSColor *)agendaDOWTextColor;
- (NSColor *)agendaEventTextColor;
- (NSColor *)agendaEventDateTextColor;
- (NSColor *)tooltipBackgroundColor;

@end
