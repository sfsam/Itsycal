//
//  ItsycalWindow.m
//  Itsycal
//
//  Created by Sanjay Madan on 12/14/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "ItsycalWindow.h"
#import "Themer.h"

static const CGFloat kMinimumSpaceBetweenWindowAndScreenEdge = 10;
static const CGFloat kArrowHeight  = 8;
static const CGFloat kCornerRadius = 10;
static const CGFloat kBorderWidth  = 1;
static const CGFloat kMarginWidth  = 0;
static const CGFloat kWindowTopMargin    = kCornerRadius + kBorderWidth + kArrowHeight;
static const CGFloat kWindowSideMargin   = kMarginWidth  + kBorderWidth;
static const CGFloat kWindowBottomMargin = kCornerRadius + kBorderWidth;

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
    self = [super initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    if (self) {
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self setLevel:NSMainMenuWindowLevel];
        [self setMovableByWindowBackground:NO];
        [self setCollectionBehavior:NSWindowCollectionBehaviorMoveToActiveSpace];
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

- (void)positionRelativeToRect:(NSRect)rect screenMaxX:(CGFloat)screenMaxX
{
    // Calculate window's top left point.
    // First, center window under status item.
    CGFloat w = NSWidth(self.frame);
    CGFloat x = roundf(NSMidX(rect) - w / 2);
    CGFloat y = NSMinY(rect) - 2;
    
    // If the calculated x position puts the window too
    // far to the right, shift the window left.
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
    
    [self invalidateShadow];
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
    
    // The rectangular part of frame view must be inset and
    // shortened to make room for the border and arrow.
    NSRect rect = NSInsetRect(self.bounds, kBorderWidth, kBorderWidth);
    rect.size.height -= kArrowHeight;
    
    // Do we need to draw the whole window?
    // If dirtyRect is inside the body of the window, we can just fill it.
    NSRect bodyRect = NSInsetRect(rect, 1, kCornerRadius);
    if (NSContainsRect(bodyRect, dirtyRect)) {
        [Theme.mainBackgroundColor setFill];
        NSRectFill(dirtyRect);
        return;
    }
    
    // We need to draw the whole window.

    [[NSColor clearColor] set];
    NSRectFill(self.bounds);
    
    NSBezierPath *rectPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:kCornerRadius yRadius:kCornerRadius];
    
    // Append the arrow to the body if its right ege is inside
    // the right edge of the body (taking into account the corner
    // radius). This accounts for the edge-case where Itsycal is
    // all the way to the right in the menu bar. This is possible
    // if the user has a 3rd party app like Bartender.
    CGFloat curveOffset = 5;
    CGFloat arrowMidX = (_arrowMidX == 0) ? NSMidX(self.frame) : _arrowMidX;
    CGFloat arrowRightEdge = arrowMidX + curveOffset + kArrowHeight;
    CGFloat bodyRightEdge = NSMaxX(rect) - kCornerRadius;
    if (arrowRightEdge < bodyRightEdge) {
        NSBezierPath *arrowPath = [NSBezierPath bezierPath];
        CGFloat x = arrowMidX - kArrowHeight - curveOffset;
        CGFloat y = NSHeight(self.frame) - kArrowHeight - kBorderWidth;
        [arrowPath moveToPoint:NSMakePoint(x, y)];
        [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, kArrowHeight)];
        [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, -kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, -kArrowHeight)];
        [rectPath appendBezierPath:arrowPath];
    }
    [Theme.windowBorderColor setStroke];
    [rectPath setLineWidth:2*kBorderWidth];
    [rectPath stroke];
    [Theme.mainBackgroundColor setFill];
    [rectPath fill];
}

@end
