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
        // The frame view draws the window. Its safe area excludes
        // the border and arrow, so views placed in the window should
        // be constrained to its safeAreaLayoutGuide.
        [self setContentView:[ItsycalWindowFrameView new]];
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
    ItsycalWindowFrameView *frameView = (ItsycalWindowFrameView *)self.contentView;
    frameView.arrowMidX = NSMidX([self convertRectFromScreen:rect]);
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

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.additionalSafeAreaInsets = NSEdgeInsetsMake(kWindowTopMargin, kWindowSideMargin, kWindowBottomMargin, kWindowSideMargin);
    }
    return self;
}

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
