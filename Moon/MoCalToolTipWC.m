//
//  MoCalToolTipWC.m
//  
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoCalToolTipWC.h"

static CGFloat kToolipWindowWidth = 200;

// Implementation at bottom.
@interface MoCalTooltipWindow : NSWindow @end
@interface MoCalTooltipContentView : NSView @end

#pragma mark -
#pragma mark MoCalTooltipWC

// =========================================================================
// MoCalTooltipWC
// =========================================================================

@implementation MoCalToolTipWC
{
    NSRect _positioningRect;
}

- (instancetype)init
{
    return [super initWithWindow:[MoCalTooltipWindow new]];
}

- (void)showTooltipForDate:(MoDate)date relativeToRect:(NSRect)rect
{
    _positioningRect = rect;
    if (self.vc) {
        [self.vc toolTipForDate:date];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showTooltip) object:nil];
    NSTimeInterval delay = self.window.occlusionState & NSWindowOcclusionStateVisible ? 0 : 1;
    [self performSelector:@selector(showTooltip) withObject:nil afterDelay:delay];
}

- (void)endTooltip
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showTooltip) object:nil];
    [self.window orderOut:nil];
}

- (void)showTooltip
{
    [self positionTooltip];
    [self showWindow:self];
}

- (void)positionTooltip
{
    NSRect frame = self.window.frame;
    frame.origin.x = roundf(NSMidX(_positioningRect) - NSWidth(frame)/2);
    frame.origin.y = _positioningRect.origin.y - NSHeight(frame) - 3;
    NSScreen *primaryScreen = [[NSScreen screens] objectAtIndex:0];
    if (NSMaxX(frame) + 5 > NSMaxX(primaryScreen.frame)) {
        frame.origin.x = NSMaxX(primaryScreen.frame) - NSWidth(frame) - 5;
    }
    [self.window setFrame:frame display:YES animate:NO];
}

@end

#pragma mark-
#pragma mark Tooltip window and content view

// =========================================================================
// MoCalTooltipWindow
// =========================================================================

@implementation MoCalTooltipWindow

- (instancetype)init
{
    self = [super initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    if (self) {
        self.backgroundColor = [NSColor clearColor];
        self.opaque = NO;
        self.level = NSPopUpMenuWindowLevel;
        self.movableByWindowBackground = NO;
        self.ignoresMouseEvents = YES;
        self.hasShadow = YES;

        // Draw tooltip background and fix tooltip width.
        self.contentView = [MoCalTooltipContentView new];
        [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:kToolipWindowWidth]];
    }
    return self;
}

@end

// =========================================================================
// MoCalTooltipContentView
// =========================================================================

@implementation MoCalTooltipContentView

- (void)drawRect:(NSRect)dirtyRect
{
    // A yellow rounded rect with a light gray border.
    NSRect r = NSInsetRect(self.bounds, 1, 1);
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:4 yRadius:4];
    [[NSColor colorWithWhite:0 alpha:0.25] setStroke];
    [[NSColor colorWithRed:1 green:1 blue:0.95 alpha:1] setFill];
    [p setLineWidth: 2];
    [p stroke];[p fill];
}

@end
