// Created by Sanjay Madan on 7/27/18
// Copyright (c) 2018 mowglii.com

#import <Foundation/Foundation.h>

// NSUserDefaults key
extern NSString * const kSizePreference;

// Notification name
extern NSString * const kSizeDidChangeNotification;

#define FONT_SIZE_SMALL 11
#define FONT_SIZE_MEDIUM 13
#define FONT_SIZE_LARGE 15

// Convenience macro for notification observer for sizeable components
#define REGISTER_FOR_SIZE_CHANGE [[NSNotificationCenter defaultCenter] \
                                   addObserverForName:kSizeDidChangeNotification \
                                   object:nil queue:[NSOperationQueue mainQueue] \
                                   usingBlock:^(NSNotification *note) { \
                                   [self sizeChanged:nil];}];

typedef enum : NSInteger {
    SizePreferenceSmall = 0,
    SizePreferenceMedium = 1,
    SizePreferenceLarge = 2
} SizePreference;

@interface Sizer : NSObject

// Global constant for shared controller instance (like NSApp).
extern Sizer *SizePref;

@property (nonatomic) SizePreference sizePreference;
@property (nonatomic, readonly) CGFloat fontSize;
@property (nonatomic, readonly) CGFloat calendarTitleFontSize;
@property (nonatomic, readonly) CGFloat cellSize;
@property (nonatomic, readonly) CGFloat cellTextFieldVerticalSpace;
@property (nonatomic, readonly) CGFloat cellDotWidth;
@property (nonatomic, readonly) CGFloat cellRadius;
@property (nonatomic, readonly) CGFloat tooltipWidth;
@property (nonatomic, readonly) CGFloat agendaEventLeadingMargin;
@property (nonatomic, readonly) CGFloat agendaDotWidth;
@property (nonatomic, readonly) NSString *videoImageName;

+ (instancetype)shared;

@end
