//
//  MoCalToolTipWC.m
//  
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoCalToolTipWC.h"
#import "Themer.h"
#import "Sizer.h"

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
    NSTimer *_fadeTimer;
    NSRect   _positioningRect;
    NSRect   _screenFrame;
}

- (instancetype)init
{
    return [super initWithWindow:[MoCalTooltipWindow new]];
}

- (void)showTooltipForDate:(MoDate)date relativeToRect:(NSRect)rect screenFrame:(NSRect)screenFrame
{
    _positioningRect = rect;
    _screenFrame = screenFrame;
    BOOL dateHasEvent = NO;
    if (self.vc) {
        dateHasEvent = [self.vc toolTipForDate:date];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showTooltip) object:nil];
    if (!dateHasEvent) {
        [self hideTooltip];
        return;
    }
    if (self.window.occlusionState & NSWindowOcclusionStateVisible) {
        // Switching from one tooltip to another
        [_fadeTimer invalidate];
        _fadeTimer = nil;
        [self performSelector:@selector(showTooltip) withObject:nil afterDelay:0];
    }
    else {
        // Showing a tooltip for the first time
        [self performSelector:@selector(showTooltip) withObject:nil afterDelay:1];
    }
}

- (void)positionTooltip
{
    NSRect frame = self.window.frame;
    frame.origin.x = roundf(NSMidX(_positioningRect) - NSWidth(frame)/2);
    frame.origin.y = _positioningRect.origin.y - NSHeight(frame) - 3;
    CGFloat screenMaxX = NSMaxX(_screenFrame);
    if (NSMaxX(frame) + 5 > screenMaxX) {
        frame.origin.x = screenMaxX - NSWidth(frame) - 5;
    }
    [self.window setFrame:frame display:YES animate:NO];
}

- (void)showTooltip
{
    [self positionTooltip];
    [self showWindow:self];
    [self.window setAlphaValue:1];
}

- (void)endTooltip
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showTooltip) object:nil];
    [_fadeTimer invalidate];
    _fadeTimer = nil;
    [self.window orderOut:nil];
}

- (void)hideTooltip
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showTooltip) object:nil];
    if (self.window.occlusionState & NSWindowOcclusionStateVisible &&
        _fadeTimer == nil) {
        _fadeTimer = [NSTimer scheduledTimerWithTimeInterval:1/30. target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    }
}

- (void)tick:(NSTimer *)timer
{
    CGFloat alpha = self.window.alphaValue - 0.07;
    if (alpha <= 0) {
        [self endTooltip];
    }
    else {
        self.window.alphaValue = alpha;
    }
}

@end

#pragma mark-
#pragma mark Tooltip window and content view

// =========================================================================
// MoCalTooltipWindow
// =========================================================================

@implementation MoCalTooltipWindow
{
    NSLayoutConstraint *_tooltipWidthConstraint;
}

- (instancetype)init
{
    self = [super initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    if (self) {
        self.backgroundColor = [NSColor clearColor];
        self.opaque = NO;
        self.level = NSPopUpMenuWindowLevel;
        self.movableByWindowBackground = NO;
        self.ignoresMouseEvents = YES;
        self.hasShadow = YES;

        // Draw tooltip background and fix tooltip width.
        self.contentView = [MoCalTooltipContentView new];
        _tooltipWidthConstraint = [self.contentView.widthAnchor constraintEqualToConstant:SizePref.tooltipWidth];
        _tooltipWidthConstraint.active = YES;
        
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)sizeChanged:(id)sender
{
    _tooltipWidthConstraint.constant = SizePref.tooltipWidth;
}

@end

// =========================================================================
// MoCalTooltipContentView
// =========================================================================

@implementation MoCalTooltipContentView

- (void)drawRect:(NSRect)dirtyRect
{
    // A rounded rect with a light gray border.
    NSRect r = NSInsetRect(self.bounds, 1, 1);
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:5 yRadius:5];
    [Theme.windowBorderColor setStroke];
    [p setLineWidth:2];
    [p stroke];
    [Theme.tooltipBackgroundColor setFill];
    [p fill];
}

@end
