// Created by Sanjay Madan on 7/27/18
// Copyright (c) 2018 mowglii.com

#import "Sizer.h"
#import "Itsycal.h"

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

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kShowLunarCalendar options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

- (void)dealloc {
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowLunarCalendar];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:kShowLunarCalendar]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kSizeDidChangeNotification object:nil];
    }
}

- (void)setSizePreference:(SizePreference)sizePreference {
    _sizePreference = sizePreference;
    // Post notification on the main thread because the selector,
    // @selector(sizeChanged:), updates the UI and therefore must
    // run on the main thread. See the REGISTER_FOR_SIZE_CHANGE
    // macro in Sizer.h.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSizeDidChangeNotification object:nil];
    });
}

- (CGFloat)fontSize {
    return SML_MED_LRG(FONT_SIZE_SMALL, FONT_SIZE_MEDIUM, FONT_SIZE_LARGE);
}

- (CGFloat)calendarTitleFontSize {
    return SML_MED_LRG(14, 16, 18);
}

- (CGFloat)cellSize {
    CGFloat size = SML_MED_LRG(23, 28, 32);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowLunarCalendar]) {
        size += 14;
    }
    return size;
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
