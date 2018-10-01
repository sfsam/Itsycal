//
//  MoButton.m
//  
//
//  Created by Sanjay Madan on 2/11/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoButton.h"

@implementation MoButton

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.bordered = NO;
        self.imagePosition = NSImageOnly;
        [self setButtonType:NSButtonTypeMomentaryChange];
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    return self.image.size;
}

- (void)setImage:(NSImage *)image
{
    [super setImage:image];
    // Create a default alternateImage. We will use
    // this as the alternate image if the user doesn't
    // provide one of their own.
    self.alternateImage = [NSImage imageWithSize:image.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [image drawInRect:dstRect];
        [[NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1] set];
        NSRectFillUsingOperation(dstRect, NSCompositingOperationSourceAtop);
        return YES;
    }];
}

@end
