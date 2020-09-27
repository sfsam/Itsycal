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
        [NSColor.controlAccentColor set];
        NSRectFillUsingOperation(dstRect, NSCompositingOperationSourceAtop);
        return YES;
    }];
}

- (void)setActionBlock:(void (^)(void))actionBlock
{
    if (actionBlock) {
        _actionBlock = [actionBlock copy];
        self.target = self;
        self.action = @selector(doActionBlock:);
    }
    else {
        _actionBlock = nil;
        self.target = nil;
        self.action = NULL;
    }
}

- (void)doActionBlock:(id)sender
{
    self.actionBlock();
}

@end
