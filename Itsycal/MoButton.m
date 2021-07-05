//
//  MoButton.m
//  
//
//  Created by Sanjay Madan on 2/11/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoButton.h"

@implementation MoButton
{
    NSBox *_hoverBox;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.imagePosition = NSImageOnly;
        [self setButtonType:NSButtonTypeMomentaryChange];
        _hoverBox = [NSBox new];
        _hoverBox.boxType = NSBoxCustom;
        _hoverBox.borderWidth = 0;
        _hoverBox.cornerRadius = 4;
        _hoverBox.alphaValue = 0.08;
        _hoverBox.fillColor = NSColor.clearColor;
        _hoverBox.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _hoverBox.frame = self.bounds;
        [self addSubview:_hoverBox];
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

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self evaluateHover];
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

- (void)updateTrackingAreas
{
    for (NSTrackingArea *area in self.trackingAreas) {
        [self removeTrackingArea:area];
    }
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
    [self addTrackingArea:area];
    [self evaluateHover];
    [super updateTrackingAreas];
}

- (void)evaluateHover
{
    NSPoint mouseLocation = [self.window mouseLocationOutsideOfEventStream];
    mouseLocation = [self convertPoint:mouseLocation fromView:nil];
    if (NSPointInRect(mouseLocation, self.bounds)) {
        [self showHoverEffect:YES];
    } else {
        [self showHoverEffect:NO];
    }
}

- (void)mouseEntered:(NSEvent *)event
{
    [self showHoverEffect:YES];
}

- (void)mouseExited:(NSEvent *)event
{
    [self showHoverEffect:NO];
}

- (void)showHoverEffect:(BOOL)show
{
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.15;
        _hoverBox.animator.fillColor = show && self.enabled ? NSColor.controlTextColor : NSColor.clearColor;
    }];
}

@end
