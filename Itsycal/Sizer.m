// Created by Sanjay Madan on 7/27/18
// Copyright (c) 2018 mowglii.com

#import "Sizer.h"

// NSUserDefaults key
NSString * const kSizePreference = @"SizePreference";

// Notification names
NSString * const kSizeDidChangeNotification = @"SizeDidChangeNotification";

#define SMALL_OR_BIG(sm, bg) (self.sizePreference == SizePreferenceLarge ? (bg) : (sm))

@implementation Sizer

+ (instancetype)shared {
    static Sizer *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[Sizer alloc] init];
    });
    return shared;
}

- (void)setSizePreference:(SizePreference)sizePreference {
    _sizePreference = sizePreference;
    [[NSNotificationCenter defaultCenter] postNotificationName:kSizeDidChangeNotification object:nil];
}

- (CGFloat)cellSize {
    return SMALL_OR_BIG(23, 28);
}

- (CGFloat)cellTextFieldVerticalSpace {
    return SMALL_OR_BIG(2, 1);
}

- (CGFloat)cellDotWidth {
    return SMALL_OR_BIG(3, 4);
}

- (CGFloat)fontSize {
    return SMALL_OR_BIG(11, 13);
}

- (CGFloat)calendarTitleFontSize {
    return SMALL_OR_BIG(14, 16);
}

@end
