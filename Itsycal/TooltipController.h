//
//  Created by Sanjay Madan on 11/1/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// What a tooltip shows. Before showing it, the controller asks it to
// lay out its view within a maximum height, then puts the view in
// the tooltip at the size it returns.
@protocol TooltipContent <NSObject>
@property (nonatomic, readonly) NSView *tooltipView;
// Lay out tooltipView to fit within maxHeight (CGFLOAT_MAX for no
// limit) and return its size, which becomes the tooltip's size.
- (NSSize)layoutTooltipViewWithMaxHeight:(CGFloat)maxHeight;
@end

// Returns the target's content now, or nil if it has none (a day with
// no events), in which case the view isn't a target. Called each time
// the tooltip needs the content, so it can change.
typedef id<TooltipContent> _Nullable (^TooltipContentProvider)(void);

// Shows one tooltip at a time for the controls of Itsycal's window:
// calendar days (their events) and buttons (a label and the button's
// shortcut). The first tooltip waits a moment; after that, tooltips
// swap at once while one is showing, and for a short while after it
// fades. A click or a key press hides the tooltip at once.
// Tooltips only display information: they ignore the mouse.
@interface TooltipController : NSObject

// Targets that track the pointer themselves (calendar days) report
// it with these. A target is identified by its view, which the
// tooltip is placed against.
- (void)pointerEnteredTarget:(NSView *)target content:(TooltipContentProvider)content;
- (void)pointerExitedTarget:(NSView *)target;

// Gives a view (a button) a tooltip that shows a label and an optional
// shortcut badge. The controller tracks the pointer over the view.
// label is called each time the tooltip shows, so it can change.
// shortcut is the badge's text; when it's nil and the view is a button,
// the badge shows the button's key equivalent, if any. Sets the view's
// accessibility label and help, and removes its system tooltip.
- (void)addTooltipToView:(NSView *)view label:(NSString *(^)(void))label shortcut:(nullable NSString *)shortcut;

// Hides the tooltip at once, without animating, and cancels a pending
// one. The next tooltip waits the full delay.
- (void)hideImmediately;

// Targets' content has changed (events changed). Updates a showing
// tooltip in place, or fades it out if its target has no content now.
// A pending tooltip will show the new content.
- (void)reloadContent;

@end

NS_ASSUME_NONNULL_END
