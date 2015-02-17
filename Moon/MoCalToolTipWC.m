//
//  MoCalToolTipWC.m
//  
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoCalToolTipWC.h"

// Implementation at bottom.
@interface MoCalTooltipWindow : NSWindow @end
@interface MoCalTooltipContentView : NSView @end

// =========================================================================
// MoCalTooltipWC
// =========================================================================

#pragma mark -
#pragma mark MoCalTooltipWC

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
    NSTimeInterval delay = self.window.occlusionState & NSWindowOcclusionStateVisible ? 0.1 : 1;
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
    CGFloat screenMaxX = NSMaxX(primaryScreen.frame);
    if (frame.origin.x + NSWidth(frame) + 5 > screenMaxX) {
        frame.origin.x = screenMaxX - NSWidth(frame) - 5;
    }
    [self.window setFrame:frame display:YES animate:NO];
}

@end

// =========================================================================
// MoCalTooltipWindow
// =========================================================================

#pragma mark-
#pragma mark MoCalTooltipWindow

@implementation MoCalTooltipWindow

- (instancetype)init
{
    self = [super initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    if (self) {
        self.contentView = [MoCalTooltipContentView new];
        self.backgroundColor = [NSColor clearColor];
        self.opaque = NO;
        self.level = NSPopUpMenuWindowLevel;
        self.movableByWindowBackground = NO;
        self.ignoresMouseEvents = YES;
        self.hasShadow = YES;
        // Fade out when -[NSWindow orderOut:] is called.
        self.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
    }
    return self;
}

@end

// =========================================================================
// MoCalTooltipContentView
// =========================================================================

#pragma mark-
#pragma mark MoCalTooltipContentView

@implementation MoCalTooltipContentView

- (void)drawRect:(NSRect)dirtyRect
{
    // A yellow rounded rect with a light gray border.
    NSRect r = NSInsetRect(self.bounds, 1, 1);
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:2 yRadius:2];
    [[NSColor colorWithDeviceWhite:0 alpha:0.25] setStroke];
    [[NSColor colorWithDeviceRed:1 green:1 blue:0.9 alpha:1] setFill];
    [p setLineWidth: 2];
    [p stroke];[p fill];
}

@end
