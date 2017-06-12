//
//  Created by Sanjay Madan on 2/23/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "MoCalResizeHandle.h"
#import "ItsyColors.h"

@implementation MoCalResizeHandle
{
    NSImage *_dot;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        NSRect dotRect = NSMakeRect(0, 0, 4, 4);
        _dot = [NSImage imageWithSize:dotRect.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            NSGradient *g = [[NSGradient alloc] initWithColors:@[
                [ItsyColors getPrimaryTextColor],
                [ItsyColors getSecondaryTextColor]]];
            [g drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:dotRect] angle:-90];
            return YES;
        }];
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[ItsyColors getPrimaryBackgroundColor] setFill];
    NSRectFill(NSMakeRect(0, 0, NSWidth(self.bounds), 6));
    CGFloat x = roundf((NSWidth(self.bounds) - _dot.size.width)/2.0);
    CGFloat y = roundf((6 - _dot.size.height)/2.0);
    [_dot drawAtPoint:NSMakePoint(x, y) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
}

@end
