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
