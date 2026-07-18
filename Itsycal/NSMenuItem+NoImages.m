//
//  Created by Sanjay Madan on 3/25/26.
//

// This code is adapted from Brent Simmons' NetNewsWire.
// It enables us to disable the menu icons introduced in macOS 26.
// If we want select menu items to have icons, we can enable them.
// MIT License
// https://github.com/Ranchero-Software/NetNewsWire

#import "NSMenuItem+NoImages.h"
#import <objc/runtime.h>

static void *kShouldShowImageKey = &kShouldShowImageKey;

@implementation NSMenuItem (NoImages)

+ (void)rs_disableImages
{
    Method originalMethod = class_getInstanceMethod(self, @selector(image));
    Method swizzledMethod = class_getInstanceMethod(self, @selector(rs_swizzledImage));

    if (originalMethod && swizzledMethod) {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (NSImage *)rs_swizzledImage
{
    if (self.rs_shouldShowImage) {
        // Call the original getter (now swapped to mo_swizzledImage)
        return [self rs_swizzledImage];
    }
    return nil;
}

- (BOOL)rs_shouldShowImage
{
    NSNumber *value = objc_getAssociatedObject(self, kShouldShowImageKey);
    return value.boolValue;
}

- (void)setRs_shouldShowImage:(BOOL)shouldShowImage
{
    objc_setAssociatedObject(self, kShouldShowImageKey, @(shouldShowImage), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
