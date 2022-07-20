// Created by Sanjay Madan on 7/27/18
// Copyright (c) 2018 mowglii.com

#import "Sizer.h"
#import "Itsycal.h"
#import <Cocoa/Cocoa.h>

// NSUserDefaults key
NSString * const kSizePreference = @"SizePreference";

// Notification names
NSString * const kSizeDidChangeNotification = @"SizeDidChangeNotification";

#define SML_MED_LRG(sml, med, lrg) \
            (self.sizePreference == SizePreferenceMedium ? med \
            : (self.sizePreference == SizePreferenceLarge ? lrg : sml))


@implementation Sizer

Sizer *SizePref = nil;

+ (instancetype)shared {
    static Sizer *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[Sizer alloc] init];
        SizePref = shared;
    });
    return shared;
}

- (void)setSizePreference:(SizePreference)sizePreference {
    _sizePreference = sizePreference;
    [[NSNotificationCenter defaultCenter] postNotificationName:kSizeDidChangeNotification object:nil];
}

- (void)setShowLunar:(BOOL)showLunar {
    _showLunar = showLunar;
    [[NSNotificationCenter defaultCenter] postNotificationName:kSizeDidChangeNotification object:nil];
}

- (CGFloat)fontSize {
    return SML_MED_LRG(FONT_SIZE_SMALL, FONT_SIZE_MEDIUM, FONT_SIZE_LARGE);
}

- (CGFloat)lunarDatefontSize {
    return SML_MED_LRG(8, 9, 11);
}

- (CGFloat)calendarTitleFontSize {
    return SML_MED_LRG(14, 16, 18);
}

- (CGSize)cellSize {
    if(!_showLunar) {
        CGFloat width = SML_MED_LRG(23, 28, 32);
        return  CGSizeMake(width, width);
    } else {
        return CGSizeMake(SML_MED_LRG(28, 35, 37), SML_MED_LRG(37, 41, 46));
    }
}

- (CGFloat)cellBorderWidth {
    return SML_MED_LRG(2, 2, 2);
}

- (CGFloat)cellTextFieldVerticalSpace {
    return SML_MED_LRG(2, 2, 2);
}

- (CGFloat)cellDotWidth {
    return SML_MED_LRG(3, 4, 5);
}

- (CGFloat)cellRadius {
    return SML_MED_LRG(2, 3, 4);
}

- (CGFloat)tooltipWidth {
    return SML_MED_LRG(200, 236, 264);
}

- (CGFloat)agendaDotWidth {
    return SML_MED_LRG(6, 7, 8);
}

- (CGFloat)agendaEventLeadingMargin {
    return SML_MED_LRG(21, 22, 24);
}

- (NSString *)videoImageName {
    return SML_MED_LRG(@"video14", @"video16", @"video18");
}

@end
