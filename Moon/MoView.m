//
//  MoView.m
//  
//
//  Created by Sanjay Madan on 2/25/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoView.h"

@implementation MoView

- (BOOL)isOpaque
{
    return self.viewIsOpaque;
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    _backgroundColor = backgroundColor;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.backgroundColor) {
        [self.backgroundColor set];
        NSRectFillUsingOperation(self.bounds, NSCompositeSourceOver);
    }
}

@end
