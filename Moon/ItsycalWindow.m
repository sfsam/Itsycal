//
//  ItsycalWindow.m
//  Itsycal
//
//  Created by Sanjay Madan on 12/14/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "ItsycalWindow.h"

static const CGFloat kMinimumSpaceBetweenWindowAndScreenEdge = 10;
static const CGFloat kArrowHeight  = 8;
static const CGFloat kCornerRadius = 8;
static const CGFloat kBorderWidth  = 1;
static const CGFloat kShadowWidth  = 12;
static const CGFloat kWindowTopMargin    = kCornerRadius + kBorderWidth + kArrowHeight;
static const CGFloat kWindowSideMargin   = kBorderWidth  + kShadowWidth;
static const CGFloat kWindowBottomMargin = kCornerRadius + kBorderWidth + kShadowWidth + kShadowWidth/2;

@interface ItsycalWindowFrameView : NSView
@property (nonatomic, assign) CGFloat arrowMidX;
@end

#pragma mark -
#pragma mark ItsycalWindow

// =========================================================================
// ItsycalWindow
// =========================================================================

@implementation ItsycalWindow
{
    NSView *_childContentView;
}

- (id)init
{
    self = [super initWithContentRect:NSZeroRect styleMask:NSNonactivatingPanelMask backing:NSBackingStoreBuffered defer:NO];
    if (self) {
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self setLevel:NSMainMenuWindowLevel];
        [self setMovableByWindowBackground:NO];
        [self setHasShadow:NO];
        // Fade out when -[NSWindow orderOut:] is called.
        [self setAnimationBehavior:NSWindowAnimationBehaviorUtilityWindow];
    }
    return self;
}

- (BOOL)canBecomeMainWindow
{
    return NO;
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)setContentView:(NSView *)aView
{
    // Instead of setting aView as the contentView, we set
    // our own frame view (which draws the window) as the
    // contentView and then set aView as its subview.
    // We keep a reference to aView called _childContentView.
    // So...
    // [self  contentView] returns _childContentView
    // [super contentView] returns our frame view
    
    if ([_childContentView isEqualTo:aView]) {
        return;
    }
    ItsycalWindowFrameView *frameView = [super contentView];
    if (!frameView) {
        frameView = [[ItsycalWindowFrameView alloc] initWithFrame:NSZeroRect];
        frameView.translatesAutoresizingMaskIntoConstraints = YES;
        frameView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [super setContentView:frameView];
    }
    if (_childContentView) {
        [_childContentView removeFromSuperview];
        _childContentView = nil;
    }
    if (aView == nil) {
        return;
    }
    _childContentView = aView;
    _childContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [frameView addSubview:_childContentView];
    [frameView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(m)-[_childContentView]-(m)-|" options:0 metrics:@{ @"m" : @(kWindowSideMargin) } views:NSDictionaryOfVariableBindings(_childContentView)]];
    [frameView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(tm)-[_childContentView]-(bm)-|" options:0 metrics:@{ @"tm" : @(kWindowTopMargin), @"bm" : @(kWindowBottomMargin) } views:NSDictionaryOfVariableBindings(_childContentView)]];
}

- (NSView *)contentView
{
    return _childContentView;
}

- (NSRect)convertRectToScreen:(NSRect)aRect
{
    NSRect rect = [super convertRectToScreen:aRect];
    // Right now, rect is the answer for our frame view.
    // What we want is the answer for _childContentView.
    // So, we offset by the amount _childContentView is
    // offset within our frame view.
    return NSOffsetRect(rect, kWindowSideMargin, kWindowBottomMargin);
}

- (NSRect)convertRectFromScreen:(NSRect)aRect
{
    // See comment for -convertRectToScreen:.
    NSRect rect = [super convertRectFromScreen:aRect];
    return NSOffsetRect(rect, kWindowSideMargin, kWindowBottomMargin);
}

- (void)positionRelativeToRect:(NSRect)rect screenFrame:(NSRect)screenFrame
{
    // Calculate window's top left point.
    // First, center window under status item.
    CGFloat w = NSWidth(self.frame);
    CGFloat x = roundf(NSMidX(rect) - w / 2);
    CGFloat y = NSMinY(rect) - 2;
    
    // If the calculated x position puts the window too
    // far to the right, shift the window left.
    CGFloat screenMaxX = NSMaxX(screenFrame);
    if (x + w + kMinimumSpaceBetweenWindowAndScreenEdge > screenMaxX) {
        x = screenMaxX - w - kMinimumSpaceBetweenWindowAndScreenEdge;
    }
    
    // Set the window position.
    [self setFrameTopLeftPoint:NSMakePoint(x, y)];

    // Tell the frame view where to draw the arrow.
    ItsycalWindowFrameView *frameView = [super contentView];
    // We call super because we want the midX for the frame view,
    // not the _childContentView, since we use the midX to draw
    // the frame view.
    frameView.arrowMidX = NSMidX([super convertRectFromScreen:rect]);
    [frameView setNeedsDisplay:YES];
}

@end

#pragma mark -
#pragma mark ItsycalWindowFrameView

// =========================================================================
// ItsycalWindowFrameView
// =========================================================================

@implementation ItsycalWindowFrameView

- (void)drawRect:(NSRect)dirtyRect
{
    // Draw the window background with the little arrow
    // at the top.
    
    [[NSColor clearColor] set];
    NSRectFill(self.bounds);
    
    // The rectangular part of frame view must be inset and
    // offset to make room for the arrow and drop shadow.
    NSRect rect = NSInsetRect(self.bounds, kWindowSideMargin, 0);
    rect.origin.y = kBorderWidth + kShadowWidth + kShadowWidth/2;
    rect.size.height -= (kArrowHeight + kShadowWidth + kShadowWidth/2 + 2*kBorderWidth);
    NSBezierPath *rectPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:kCornerRadius yRadius:kCornerRadius];
    
    // The arrow is in the middle of the frame view.
    NSBezierPath *arrowPath = [NSBezierPath bezierPath];
    CGFloat curveOffset = 5;
    CGFloat arrowMidX = (_arrowMidX == 0) ? NSMidX(self.frame) : _arrowMidX;
    CGFloat x = arrowMidX - kArrowHeight - curveOffset;
    CGFloat y = NSHeight(self.frame) - kArrowHeight - kBorderWidth;
    [arrowPath moveToPoint:NSMakePoint(x, y)];
    [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, kArrowHeight)];
    [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, -kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, -kArrowHeight)];
    
    // Combine rectangular and arrow parts; stroke and fill.
    static NSShadow *shadow = nil;
    if (shadow == nil) {
        shadow = [NSShadow new];
        shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.5];
        shadow.shadowBlurRadius = kShadowWidth;
        shadow.shadowOffset = NSMakeSize(0, -kShadowWidth/2);
    }
    [shadow set];
    [[NSColor colorWithWhite:0 alpha:0.4] setStroke];
    [[NSColor whiteColor] setFill];
    [rectPath appendBezierPath:arrowPath];
    [rectPath setLineWidth:2*kBorderWidth];
    [rectPath stroke];
    [rectPath fill];
}

@end
