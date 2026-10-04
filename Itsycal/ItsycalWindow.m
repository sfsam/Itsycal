//
//  ItsycalWindow.m
//  Itsycal
//
//  Created by Sanjay Madan on 12/14/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "ItsycalWindow.h"
#import <QuartzCore/QuartzCore.h>
#import "Themer.h"

static const CGFloat kMinimumSpaceBetweenWindowAndScreenEdge = 10;
static const CGFloat kArrowHeight  = 8;
static const CGFloat kCornerRadius = 16;
static const CGFloat kVerticalPadding = 11;

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
        // the arrow and padding, so views placed in the window should
        // be constrained to its safeAreaLayoutGuide. The system draws
        // the window's shadow around the frame view's shape.
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
    
    [self invalidateShadow];
}

@end

#pragma mark -
#pragma mark ItsycalWindowFrameView

// =========================================================================
// ItsycalWindowFrameView
// =========================================================================

@implementation ItsycalWindowFrameView
{
    CALayer *_bodyMask;
    CAShapeLayer *_arrowMask;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.additionalSafeAreaInsets = NSEdgeInsetsMake(kArrowHeight + kVerticalPadding, 0, kVerticalPadding, 0);

        // The window's shape is a rounded body with a little arrow at
        // the top. Masking our layer to that shape clips our background
        // and the content's corners. Masks use only alpha, so any opaque
        // color works.
        _bodyMask = [CALayer layer];
        _bodyMask.backgroundColor = NSColor.blackColor.CGColor;
        _bodyMask.cornerRadius = kCornerRadius;
        _bodyMask.cornerCurve = kCACornerCurveContinuous;
        _arrowMask = [CAShapeLayer layer];
        _arrowMask.fillColor = NSColor.blackColor.CGColor;
        [_bodyMask addSublayer:_arrowMask];
        self.layer.mask = _bodyMask;
    }
    return self;
}

- (void)setArrowMidX:(CGFloat)arrowMidX
{
    _arrowMidX = arrowMidX;
    [self updateMask];
}

- (void)layout
{
    [super layout];
    [self updateMask];
}

- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void)updateLayer
{
    self.layer.backgroundColor = Theme.mainBackgroundColor.CGColor;
}

- (void)updateMask
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    NSRect bodyRect = self.bounds;
    bodyRect.size.height -= kArrowHeight;
    _bodyMask.frame = bodyRect;

    // Add the arrow to the body if its right edge is inside
    // the right edge of the body (taking into account the corner
    // radius). This accounts for the edge-case where Itsycal is
    // all the way to the right in the menu bar. This is possible
    // if the user has a 3rd party app like Bartender.
    // The arrow is in _bodyMask's coordinates, whose origin is the
    // bottom left of the body. Its base extends 1pt into the body so
    // no seam shows where they meet.
    CGFloat curveOffset = 5;
    CGFloat arrowMidX = (_arrowMidX == 0) ? NSMidX(self.bounds) : _arrowMidX;
    CGFloat arrowRightEdge = arrowMidX + curveOffset + kArrowHeight;
    CGFloat bodyRightEdge = NSMaxX(bodyRect) - kCornerRadius;
    NSBezierPath *arrowPath = [NSBezierPath bezierPath];
    if (arrowRightEdge < bodyRightEdge) {
        CGFloat x = arrowMidX - kArrowHeight - curveOffset;
        CGFloat y = NSHeight(bodyRect);
        [arrowPath moveToPoint:NSMakePoint(x, y)];
        [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, kArrowHeight)];
        [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, -kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, -kArrowHeight)];
        [arrowPath relativeLineToPoint:NSMakePoint(0, -1)];
        [arrowPath lineToPoint:NSMakePoint(x, y - 1)];
        [arrowPath closePath];
    }
    _arrowMask.path = arrowPath.CGPath;

    [CATransaction commit];
}

@end
