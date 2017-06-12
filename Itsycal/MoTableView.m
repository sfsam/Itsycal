//
//  MoTableView.m
//  
//
//  Created by Sanjay Madan on 2/21/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoTableView.h"
#import "ItsyColors.h"

@implementation MoTableView
{
    NSTrackingArea  *_trackingArea;
}

@dynamic delegate;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInitForMoTableView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInitForMoTableView];
    }
    return self;
}

- (void)commonInitForMoTableView
{
    _enableHover = YES;
    _hoverRow    = -1;
    _hoverColor  = [ItsyColors getSecondaryBackgroundColor];
    
    // Notify when enclosing scrollView scrolls.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scrollViewScrolled:) name:NSViewBoundsDidChangeNotification object:[[self enclosingScrollView] contentView]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeTrackingArea:_trackingArea];
}

#pragma mark -
#pragma mark Instance methods

- (void)drawBackgroundInClipRect:(NSRect)clipRect
{
    [super drawBackgroundInClipRect:clipRect];
    
    [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        rowView.backgroundColor = [ItsyColors getPrimaryBackgroundColor];
        BOOL isGroupRow = NO;
        if ([self.delegate respondsToSelector:@selector(tableView:isGroupRow:)]) {
            isGroupRow = [self.delegate tableView:self isGroupRow:row];
        }
        if (row == self.hoverRow && isGroupRow == NO) {
            [self.hoverColor set];
            NSRect rect = NSInsetRect([self rectOfRow:row], 2, 2);
            [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:3 yRadius:3] fill];
        }
    }];
}

- (void)reloadData
{
    [super reloadData];
    [self setHoverRow:-1];
    [self evaluateForHighlight];
}

- (void)setEnableHover:(BOOL)enableHover
{
    if (enableHover != _enableHover) {
        if (enableHover == NO) {
            [self setHoverRow:-1];
        }
        _enableHover = enableHover;
        [self evaluateForHighlight];
    }
}

#pragma mark -
#pragma mark NSTrackingArea

- (void)mouseEntered:(NSEvent *)theEvent
{
    NSPoint mousePointInWindow = [theEvent locationInWindow];
    NSPoint mousePoint = [self convertPoint:mousePointInWindow fromView:nil];
    [self evaluateForHighligthAtMousePoint:mousePoint];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint mousePointInWindow = [theEvent locationInWindow];
    NSPoint mousePoint = [self convertPoint:mousePointInWindow fromView:nil];
    [self evaluateForHighligthAtMousePoint:mousePoint];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [self setHoverRow:-1];
}

- (void)updateTrackingAreas
{
    [self removeTrackingArea:_trackingArea];
    [self createTrackingArea];
    [super updateTrackingAreas];
}

- (void)createTrackingArea
{
    NSRect clipRect = self.enclosingScrollView.contentView.bounds;
    _trackingArea = [[NSTrackingArea alloc] initWithRect:clipRect options:(NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

#pragma mark -
#pragma mark Notification handlers

- (void)scrollViewScrolled:(NSNotification *)notification
{
    // Normally when the user scrolls, -updateTrackingAreas
    // is called and we could just do the evaluation there.
    // However, when the user is scrolling with inertia,
    // -updateTrackingAreas is not called so we need to
    // explicity be notified that the tableView has
    // scrolled and evaluate for highlight.
    
    [self evaluateForHighlight];
}

#pragma mark -
#pragma mark Highlight/Unhighlight

- (void)setHoverRow:(NSInteger)hoverRow
{
    if (self.enableHover == NO) return;
    
    if (hoverRow != _hoverRow) {
        _hoverRow = hoverRow;
        if ([self.delegate respondsToSelector:@selector(tableView:didHoverOverRow:)]) {
            [self.delegate tableView:self didHoverOverRow:_hoverRow];
        }
        [self setNeedsDisplay:YES];
    }
}

- (void)evaluateForHighlight
{
    if (self.enableHover == NO) return;
    
    NSPoint mousePointInWindow = [[self window] mouseLocationOutsideOfEventStream];
    NSPoint mousePoint = [self convertPoint:mousePointInWindow fromView: nil];
    [self evaluateForHighligthAtMousePoint:mousePoint];
}

- (void)evaluateForHighligthAtMousePoint:(NSPoint)mousePoint
{
    if (self.enableHover == NO ||
        !(self.window.occlusionState & NSWindowOcclusionStateVisible)) return;
    
    NSInteger hoverRow = [self rowAtPoint:mousePoint];
    if (self.hoverRow != hoverRow) {
        // We scrolled (rubberbanded) off the end of the tableView.
        if (hoverRow < 0 || hoverRow >= [self numberOfRows]) {
            hoverRow = -1;
        }
        [self setHoverRow:hoverRow];
    }
}

@end
