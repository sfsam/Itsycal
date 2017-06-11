//
//  Created by Sanjay Madan on 2/23/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "MoCalResizeHandle.h"

@implementation MoCalResizeHandle

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithWhite:0.99 alpha:1] set];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
    CGFloat handleWidth = 24;
    CGFloat handleHeight = 4;
    CGFloat x = roundf((NSWidth(self.bounds) - handleWidth)/2.0);
    CGFloat y = roundf((self.bounds.size.height - handleHeight)/2.0);
    NSRect handleRect = NSMakeRect(x, y, handleWidth, handleHeight);
    [[NSColor colorWithWhite:0.4 alpha:1] set];
    [[NSBezierPath bezierPathWithRoundedRect:handleRect xRadius:2 yRadius:2] fill];
}

@end
