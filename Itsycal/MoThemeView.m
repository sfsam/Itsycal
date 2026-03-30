//
//  Created by Sanjay Madan on 3/24/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import "MoThemeView.h"
#import "Themer.h"

// =========================================================================
// MoThemeView
// =========================================================================

@implementation MoThemeView

- (void)drawRect:(NSRect)dirtyRect
{
    [[Theme mainBackgroundColor] setFill];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
}

@end

// =========================================================================
// ThemedScroller
// =========================================================================

@implementation ThemedScroller

+ (BOOL)isCompatibleWithOverlayScrollers
{
    return self == [ThemedScroller class];
}

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
    [Theme.mainBackgroundColor set];
    NSRectFill(slotRect);
}

@end
