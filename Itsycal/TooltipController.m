//
//  Created by Sanjay Madan on 11/1/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import "TooltipController.h"
#import <QuartzCore/QuartzCore.h>
#import "Themer.h"
#import "Sizer.h"

// Timing
static const NSTimeInterval kShowDelay = 0.8;   // before the first tooltip
static const NSTimeInterval kLinger = 0.1;      // after the pointer leaves, before fading
static const NSTimeInterval kGracePeriod = 0.2; // still warm after the fade
static const NSTimeInterval kAppearDuration = 0.1;
static const NSTimeInterval kFadeDuration = 0.2;
static const CGFloat kAppearScale = 0.75;       // grows from this to full size

// Placement and shape
static const CGFloat kGap = 4;          // between the target and the tooltip
static const CGFloat kScreenInset = 6;  // from the edges of the screen's visible frame
static const CGFloat kCornerRadius = 10;

// A label tooltip's layout
static const CGFloat kLabelPaddingH = 10;
static const CGFloat kLabelPaddingV = 4;
static const CGFloat kBadgeGap = 8;
static const CGFloat kBadgePaddingH = 4;
static const CGFloat kBadgePaddingV = 1;
static const CGFloat kBadgeCornerRadius = 4;

typedef NS_ENUM(NSInteger, TooltipState) {
    TooltipStateCold,      // nothing shown
    TooltipStateWaiting,   // the show delay is running
    TooltipStateShowing,   // visible
    TooltipStateLingering, // visible; the pointer left its target
    TooltipStateFading,    // fading out
    TooltipStateGrace,     // hidden, still warm
};

// The badge text for a button's key equivalent, e.g. ⌘N. Nil if it
// has none.
static NSString *ShortcutString(NSString *keyEquivalent, NSEventModifierFlags modifierMask)
{
    if (keyEquivalent.length == 0) return nil;
    NSMutableString *shortcut = [NSMutableString new];
    if (modifierMask & NSEventModifierFlagControl) [shortcut appendString:@"⌃"];
    if (modifierMask & NSEventModifierFlagOption)  [shortcut appendString:@"⌥"];
    if (modifierMask & NSEventModifierFlagShift)   [shortcut appendString:@"⇧"];
    if (modifierMask & NSEventModifierFlagCommand) [shortcut appendString:@"⌘"];
    [shortcut appendString:keyEquivalent.uppercaseString];
    return shortcut;
}

#pragma mark -
#pragma mark Tooltip bubble

// =========================================================================
// TooltipBubbleView
// =========================================================================

// The tooltip's rounded background, which clips its content. The
// system draws the window's shadow around it.
@interface TooltipBubbleView : NSView
@end

@implementation TooltipBubbleView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.masksToBounds = YES;
    }
    return self;
}

- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void)updateLayer
{
    self.layer.backgroundColor = Theme.tooltipBackgroundColor.CGColor;
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    // A one-line tooltip is a capsule.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = MIN(kCornerRadius, newSize.height / 2);
    [CATransaction commit];
}

@end

#pragma mark -
#pragma mark Label tooltips

// =========================================================================
// TooltipBadgeView
// =========================================================================

// A shortcut in an outlined keycap.
@interface TooltipBadgeView : NSView
- (instancetype)initWithString:(NSString *)string;
@property (nonatomic, readonly) NSSize badgeSize;
@end

@implementation TooltipBadgeView
{
    NSTextField *_text;
}

- (instancetype)initWithString:(NSString *)string
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _text = [NSTextField labelWithString:string];
        _text.font = [NSFont systemFontOfSize:SizePref.fontSize - 1];
        _text.textColor = NSColor.secondaryLabelColor;
        [self addSubview:_text];
    }
    return self;
}

- (NSSize)badgeSize
{
    NSSize textSize = _text.fittingSize;
    return NSMakeSize(ceil(textSize.width) + 2 * kBadgePaddingH,
                      ceil(textSize.height) + 2 * kBadgePaddingV);
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSSize textSize = _text.fittingSize;
    _text.frame = NSMakeRect(kBadgePaddingH, kBadgePaddingV, ceil(textSize.width), ceil(textSize.height));
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect r = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:r xRadius:kBadgeCornerRadius yRadius:kBadgeCornerRadius];
    path.lineWidth = 1;
    [NSColor.tertiaryLabelColor setStroke];
    [path stroke];
}

@end

// =========================================================================
// TooltipLabelContent
// =========================================================================

// A one-line tooltip: a label and an optional shortcut badge.
@interface TooltipLabelContent : NSObject <TooltipContent>
- (instancetype)initWithLabel:(NSString *)label shortcut:(NSString *)shortcut;
@end

@implementation TooltipLabelContent
{
    NSString *_labelString;
    NSString *_shortcut;
    NSView *_view;
    NSTextField *_label;
    TooltipBadgeView *_badge;
}

- (instancetype)initWithLabel:(NSString *)label shortcut:(NSString *)shortcut
{
    self = [super init];
    if (self) {
        _labelString = [label copy];
        _shortcut = [shortcut copy];
    }
    return self;
}

- (NSView *)tooltipView
{
    // Made only when shown: content is also made just to learn that a
    // view has a tooltip.
    if (_view == nil) {
        _view = [NSView new];
        _label = [NSTextField labelWithString:_labelString];
        _label.font = [NSFont systemFontOfSize:SizePref.fontSize];
        _label.textColor = NSColor.labelColor;
        [_view addSubview:_label];
        if (_shortcut.length > 0) {
            _badge = [[TooltipBadgeView alloc] initWithString:_shortcut];
            [_view addSubview:_badge];
        }
    }
    return _view;
}

- (NSSize)layoutTooltipViewWithMaxHeight:(CGFloat)maxHeight
{
    [self tooltipView];
    // One line, so maxHeight doesn't apply.
    NSSize labelSize = _label.fittingSize;
    labelSize = NSMakeSize(ceil(labelSize.width), ceil(labelSize.height));
    NSSize badgeSize = _badge ? _badge.badgeSize : NSZeroSize;
    CGFloat width = kLabelPaddingH + labelSize.width + (_badge ? kBadgeGap + badgeSize.width : 0) + kLabelPaddingH;
    CGFloat height = MAX(labelSize.height, badgeSize.height) + 2 * kLabelPaddingV;
    _label.frame = NSMakeRect(kLabelPaddingH, round((height - labelSize.height) / 2), labelSize.width, labelSize.height);
    _badge.frame = NSMakeRect(NSMaxX(_label.frame) + kBadgeGap, round((height - badgeSize.height) / 2), badgeSize.width, badgeSize.height);
    _view.frame = NSMakeRect(0, 0, width, height);
    return _view.frame.size;
}

@end

// =========================================================================
// TooltipViewTracker
// =========================================================================

// Tracks the pointer over a view with a label tooltip (a button) and
// reports it to the controller.
@interface TooltipViewTracker : NSObject
@property (nonatomic, weak) TooltipController *controller;
@property (nonatomic, weak) NSView *view;
@property (nonatomic, copy) NSString *(^label)(void);
@property (nonatomic, copy) NSString *shortcut; // nil: the button's key equivalent
@end

@implementation TooltipViewTracker

- (NSString *)currentShortcut
{
    if (self.shortcut) return self.shortcut;
    if ([self.view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)self.view;
        return ShortcutString(button.keyEquivalent, button.keyEquivalentModifierMask);
    }
    return nil;
}

- (id<TooltipContent>)content
{
    if (self.view == nil) return nil;
    return [[TooltipLabelContent alloc] initWithLabel:self.label() shortcut:[self currentShortcut]];
}

- (void)mouseEntered:(NSEvent *)event
{
    NSView *view = self.view;
    if (view == nil) return;
    __weak typeof(self) weakSelf = self;
    [self.controller pointerEnteredTarget:view content:^id<TooltipContent>{
        return [weakSelf content];
    }];
}

- (void)mouseExited:(NSEvent *)event
{
    NSView *view = self.view;
    if (view == nil) return;
    [self.controller pointerExitedTarget:view];
}

@end

#pragma mark -
#pragma mark TooltipController

// =========================================================================
// TooltipController
// =========================================================================

@implementation TooltipController
{
    NSWindow *_window;
    TooltipBubbleView *_bubble;
    NSView *_contentView; // the shown content's view, in _bubble
    TooltipState _state;

    // The target under the pointer, if it has a tooltip.
    __weak NSView *_target;
    TooltipContentProvider _targetContent;

    // The target whose tooltip is in the window. While the tooltip
    // lingers or fades, the pointer is no longer over it.
    __weak NSView *_shownTarget;
    TooltipContentProvider _shownContent;

    // The view under the pointer that was reported to us, whether or
    // not it has a tooltip now.
    __weak NSView *_hoveredView;

    // The view the user clicked, which gets no tooltip until the
    // pointer leaves it.
    __weak NSView *_suppressedTarget;

    NSTimer *_timer;               // show delay, linger, or grace period
    CADisplayLink *_displayLink;   // drives the appear and fade animations
    CFTimeInterval _animationStart;
    BOOL _appearing;               // else fading out
    CGFloat _startScale;
    id _eventMonitor;
    NSMutableArray<TooltipViewTracker *> *_trackers;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // A borderless window the size of the tooltip. It ignores the
        // mouse, so the pointer passes through to the controls under it.
        _window = [[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
        _window.backgroundColor = NSColor.clearColor;
        _window.opaque = NO;
        _window.hasShadow = YES;
        _window.ignoresMouseEvents = YES;
        _window.level = NSPopUpMenuWindowLevel;
        _window.releasedWhenClosed = NO;
        // We animate it ourselves.
        _window.animationBehavior = NSWindowAnimationBehaviorNone;
        // Show on the active space, like Itsycal's window, including over
        // a full screen app.
        _window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace | NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorIgnoresCycle | NSWindowCollectionBehaviorFullScreenAuxiliary;
        // VoiceOver gets this information from the controls.
        _window.accessibilityElement = NO;

        _bubble = [[TooltipBubbleView alloc] initWithFrame:_window.contentView.bounds];
        _bubble.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [_window.contentView addSubview:_bubble];
        _trackers = [NSMutableArray new];

        // Clicks and key presses hide the tooltip. (Menus open with
        // one, so they hide it too.)
        __weak typeof(self) weakSelf = self;
        NSEventMask mask = NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown | NSEventMaskKeyDown;
        _eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
            [weakSelf handleEvent:event];
            return event;
        }];

        NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
        [nc addObserver:self selector:@selector(windowDidChangeOcclusionState:) name:NSWindowDidChangeOcclusionStateNotification object:nil];
        [nc addObserver:self selector:@selector(windowDidChangeFrame:) name:NSWindowDidMoveNotification object:nil];
        [nc addObserver:self selector:@selector(windowDidChangeFrame:) name:NSWindowDidResizeNotification object:nil];
        [nc addObserver:self selector:@selector(sizeChanged:) name:kSizeDidChangeNotification object:nil];
        // The theme (or the system's appearance) changed.
        [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:NULL];
    }
    return self;
}

- (void)dealloc
{
    [NSEvent removeMonitor:_eventMonitor];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [NSApp removeObserver:self forKeyPath:@"effectiveAppearance"];
    [_displayLink invalidate];
    [_timer invalidate];
}

#pragma mark -
#pragma mark Targets

- (void)addTooltipToView:(NSView *)view label:(NSString *(^)(void))label shortcut:(NSString *)shortcut
{
    TooltipViewTracker *tracker = [TooltipViewTracker new];
    tracker.controller = self;
    tracker.view = view;
    tracker.label = label;
    tracker.shortcut = shortcut;
    [_trackers addObject:tracker];

    // InVisibleRect keeps the area matched to the view as it changes.
    // The area doesn't retain its owner; _trackers does.
    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect;
    [view addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:tracker userInfo:nil]];

    // Only one tooltip shows: never the system's as well.
    view.toolTip = nil;
    view.accessibilityLabel = label();
    view.accessibilityHelp = [tracker currentShortcut];
}

- (void)pointerEnteredTarget:(NSView *)target content:(TooltipContentProvider)content
{
    _hoveredView = target;
    if (target == _suppressedTarget) return;

    // Back on the target whose tooltip is lingering: keep it as it is.
    if ((_state == TooltipStateShowing || _state == TooltipStateLingering) && target == _shownTarget) {
        [self stopTimer];
        _target = target;
        _targetContent = content;
        _state = TooltipStateShowing;
        return;
    }

    // A view whose content is nil (a day with no events) isn't a target.
    id<TooltipContent> tooltipContent = content();
    if (tooltipContent == nil) return;

    switch (_state) {
        case TooltipStateCold:
        case TooltipStateWaiting:
            // Start the delay, or restart it for this target.
            _target = target;
            _targetContent = content;
            _state = TooltipStateWaiting;
            [self runAfter:kShowDelay block:^(TooltipController *me) {
                [me showDelayEnded];
            }];
            break;
        case TooltipStateShowing:
        case TooltipStateLingering:
        case TooltipStateFading:
        case TooltipStateGrace:
            // Warm: show it at once. Swap a visible tooltip in place;
            // make a hidden one appear.
            if (![self canShowTooltipForTarget:target]) return;
            [self stopTimer];
            _target = target;
            _targetContent = content;
            [self showContent:tooltipContent forTarget:target provider:content animated:(_state == TooltipStateGrace)];
            _state = TooltipStateShowing;
            break;
    }
}

- (void)pointerExitedTarget:(NSView *)target
{
    if (target == _hoveredView) {
        _hoveredView = nil;
    }
    if (target == _suppressedTarget) {
        _suppressedTarget = nil;
    }
    // Ignore a late exit from a target we've already left (the pointer
    // can enter the next target first).
    if (target != _target) return;
    _target = nil;
    _targetContent = nil;
    if (_state == TooltipStateWaiting) {
        [self stopTimer];
        _state = TooltipStateCold;
    }
    else if (_state == TooltipStateShowing) {
        [self linger];
    }
}

#pragma mark -
#pragma mark State changes

- (void)showDelayEnded
{
    // Get the content now, so it's the latest.
    NSView *target = _target;
    id<TooltipContent> content = (target && _targetContent) ? _targetContent() : nil;
    if (_state != TooltipStateWaiting || content == nil || ![self canShowTooltipForTarget:target]) {
        _state = TooltipStateCold;
        return;
    }
    [self showContent:content forTarget:target provider:_targetContent animated:YES];
    _state = TooltipStateShowing;
}

- (void)linger
{
    _state = TooltipStateLingering;
    [self runAfter:kLinger block:^(TooltipController *me) {
        if (me->_state != TooltipStateLingering) return;
        me->_state = TooltipStateFading;
        [me startAnimationAppearing:NO];
    }];
}

- (void)fadeEnded
{
    [_window orderOut:nil];
    [self setAlpha:1 scale:1];
    _shownTarget = nil;
    _shownContent = nil;
    _state = TooltipStateGrace;
    [self runAfter:kGracePeriod block:^(TooltipController *me) {
        if (me->_state == TooltipStateGrace) {
            me->_state = TooltipStateCold;
        }
    }];
}

- (void)hideImmediately
{
    [self stopTimer];
    [self stopAnimation];
    [_window orderOut:nil];
    [self setAlpha:1 scale:1];
    _state = TooltipStateCold;
    _target = nil;
    _targetContent = nil;
    _shownTarget = nil;
    _shownContent = nil;
}

- (void)reloadContent
{
    if (_state != TooltipStateShowing && _state != TooltipStateLingering) return;
    NSView *target = _shownTarget;
    id<TooltipContent> content = (target && _shownContent) ? _shownContent() : nil;
    if (content == nil) {
        // The target has no tooltip now: fade out as if the pointer left.
        if (_state == TooltipStateShowing) {
            _target = nil;
            _targetContent = nil;
            [self linger];
        }
        return;
    }
    [self showContent:content forTarget:target provider:_shownContent animated:NO];
}

- (BOOL)canShowTooltipForTarget:(NSView *)target
{
    NSWindow *window = target.window;
    return window.isVisible && (window.occlusionState & NSWindowOcclusionStateVisible);
}

#pragma mark -
#pragma mark Showing

- (void)showContent:(id<TooltipContent>)content forTarget:(NSView *)target provider:(TooltipContentProvider)provider animated:(BOOL)animated
{
    if (target.window == nil) {
        [self hideImmediately];
        return;
    }
    [self stopAnimation];

    NSView *view = content.tooltipView;
    if (view != _contentView) {
        [_contentView removeFromSuperview];
        _contentView = view;
        [_bubble addSubview:view];
    }

    // Size and place the tooltip before it shows, so it never resizes
    // after its content changes.
    NSRect frame = [self frameForContent:content target:target];
    view.frame = (NSRect){NSZeroPoint, frame.size};
    [self setAlpha:1 scale:1];
    [_window setFrame:frame display:NO];
    [_window displayIfNeeded];
    [_window invalidateShadow];

    _shownTarget = target;
    _shownContent = provider;

    if (animated) {
        // Fade in and grow a little, or only fade with Reduce Motion.
        _startScale = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? 1 : kAppearScale;
        [self setAlpha:0 scale:_startScale];
        [_window orderFrontRegardless];
        [self startAnimationAppearing:YES];
    }
    else {
        [_window orderFrontRegardless];
    }
}

- (NSRect)frameForContent:(id<TooltipContent>)content target:(NSView *)target
{
    NSWindow *hostWindow = target.window;
    NSRect anchor = [hostWindow convertRectToScreen:[target convertRect:target.bounds toView:nil]];
    NSScreen *screen = hostWindow.screen ?: NSScreen.mainScreen;
    NSRect bounds = NSInsetRect(screen.visibleFrame, kScreenInset, kScreenInset);
    CGFloat spaceBelow = NSMinY(anchor) - kGap - NSMinY(bounds);
    CGFloat spaceAbove = NSMaxY(bounds) - kGap - NSMaxY(anchor);

    // Below the target if it fits, else above. If it fits neither way,
    // on the side with more room, with its height capped to fit.
    NSSize size = [content layoutTooltipViewWithMaxHeight:CGFLOAT_MAX];
    BOOL below = YES;
    if (size.height > spaceBelow) {
        if (size.height <= spaceAbove) {
            below = NO;
        }
        else {
            below = spaceBelow >= spaceAbove;
            size = [content layoutTooltipViewWithMaxHeight:MAX(0, below ? spaceBelow : spaceAbove)];
        }
    }

    // Centered on the target, slid to stay on the screen.
    CGFloat x = NSMidX(anchor) - size.width / 2;
    x = MAX(NSMinX(bounds), MIN(x, NSMaxX(bounds) - size.width));
    CGFloat y = below ? NSMinY(anchor) - kGap - size.height : NSMaxY(anchor) + kGap;
    NSRect frame = NSMakeRect(x, y, size.width, size.height);
    return [hostWindow backingAlignedRect:frame options:NSAlignMinXNearest | NSAlignMinYNearest | NSAlignWidthOutward | NSAlignHeightOutward];
}

#pragma mark -
#pragma mark Animation

- (void)startAnimationAppearing:(BOOL)appearing
{
    [self stopAnimation];
    _appearing = appearing;
    _animationStart = CACurrentMediaTime();
    _displayLink = [_bubble displayLinkWithTarget:self selector:@selector(animationStep:)];
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)stopAnimation
{
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)animationStep:(CADisplayLink *)displayLink
{
    NSTimeInterval duration = _appearing ? kAppearDuration : kFadeDuration;
    CGFloat t = MIN(1, (CACurrentMediaTime() - _animationStart) / duration);
    if (_appearing) {
        CGFloat eased = 1 - pow(1 - t, 3); // ease-out
        [self setAlpha:eased scale:_startScale + (1 - _startScale) * eased];
    }
    else {
        CGFloat eased = t * t; // ease-in
        [self setAlpha:1 - eased scale:1];
    }
    if (t >= 1) {
        [self stopAnimation];
        if (_appearing) {
            // The shadow may have been computed while the bubble was
            // smaller.
            [_window invalidateShadow];
        }
        else {
            [self fadeEnded];
        }
    }
}

- (void)setAlpha:(CGFloat)alpha scale:(CGFloat)scale
{
    _window.alphaValue = alpha;

    // Scale the bubble about its center. A layer scales about its
    // anchor point, so move the center to the anchor point first.
    // AppKit resets the transform when the view resizes, so this is
    // set again on every frame.
    CALayer *layer = _bubble.layer;
    CATransform3D transform = CATransform3DIdentity;
    if (scale != 1) {
        CGFloat dx = (0.5 - layer.anchorPoint.x) * NSWidth(layer.bounds);
        CGFloat dy = (0.5 - layer.anchorPoint.y) * NSHeight(layer.bounds);
        transform = CATransform3DMakeTranslation(-dx, -dy, 0);
        transform = CATransform3DConcat(transform, CATransform3DMakeScale(scale, scale, 1));
        transform = CATransform3DConcat(transform, CATransform3DMakeTranslation(dx, dy, 0));
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.transform = transform;
    [CATransaction commit];
}

#pragma mark -
#pragma mark Timer

- (void)runAfter:(NSTimeInterval)interval block:(void (^)(TooltipController *me))block
{
    [_timer invalidate];
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer timerWithTimeInterval:interval repeats:NO block:^(NSTimer *timer) {
        TooltipController *me = weakSelf;
        if (me == nil) return;
        me->_timer = nil;
        block(me);
    }];
    // Common modes, so it also fires while the mouse is being tracked.
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer
{
    [_timer invalidate];
    _timer = nil;
}

#pragma mark -
#pragma mark Events and notifications

- (void)handleEvent:(NSEvent *)event
{
    if (event.type != NSEventTypeKeyDown) {
        // No tooltip for the clicked view until the pointer leaves it,
        // even if it becomes another day (the click changed months).
        _suppressedTarget = _hoveredView;
    }
    if (_state != TooltipStateCold) {
        [self hideImmediately];
    }
}

- (void)windowDidChangeOcclusionState:(NSNotification *)notification
{
    // Itsycal's window hid (or something covered it).
    NSWindow *window = notification.object;
    if (window == _window || (window.occlusionState & NSWindowOcclusionStateVisible)) return;
    if (window == _target.window || window == _shownTarget.window) {
        [self hideImmediately];
    }
    // The pointer won't report leaving the views of a hidden window.
    if (window == _hoveredView.window) {
        _hoveredView = nil;
    }
    if (window == _suppressedTarget.window) {
        _suppressedTarget = nil;
    }
}

- (void)windowDidChangeFrame:(NSNotification *)notification
{
    // Itsycal's window moved or resized: keep the tooltip on its target.
    NSWindow *window = notification.object;
    if (window == _window || window != _shownTarget.window) return;
    [self reloadContent];
}

- (void)sizeChanged:(NSNotification *)notification
{
    [self hideImmediately];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (object == NSApp && [keyPath isEqualToString:@"effectiveAppearance"]) {
        [self hideImmediately];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
