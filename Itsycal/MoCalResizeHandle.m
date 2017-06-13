//
//  Created by Sanjay Madan on 2/23/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "MoCalResizeHandle.h"
#import "Themer.h"

@implementation MoCalResizeHandle

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        REGISTER_FOR_THEME_CHANGE;
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

- (void)themeChanged:(id)sender
{
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[[Themer shared] resizeHandleBackgroundColor] set];
    NSRect barRect = NSInsetRect(self.bounds, 3, 0);
    [[NSBezierPath bezierPathWithRoundedRect:barRect xRadius:2 yRadius:2] fill];
    
    CGFloat handleWidth = 24;
    CGFloat handleHeight = 4;
    CGFloat x = roundf((NSWidth(self.bounds) - handleWidth)/2.0);
    CGFloat y = roundf((self.bounds.size.height - handleHeight)/2.0);
    NSRect handleRect = NSMakeRect(x, y, handleWidth, handleHeight);
    [[[Themer shared] resizeHandleForegroundColor] set];
    [[NSBezierPath bezierPathWithRoundedRect:handleRect xRadius:2 yRadius:2] fill];
}

@end
