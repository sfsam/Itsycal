//
//  MoCalendar.m
//
//
//  Created by Sanjay Madan on 11/13/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoCalendar.h"
#import <QuartzCore/QuartzCore.h>
#import "MoCalCell.h"
#import "MoCalGrid.h"
#import "MoButton.h"
#import "MoVFLHelper.h"
#import "MoCalResizeHandle.h"
#import "TooltipController.h"
#import "Themer.h"
#import "Sizer.h"

NSString * const kMoCalendarNumRows = @"MoCalendarNumRows";

// The calendar shows this many rows (weeks) of dates.
static const NSInteger kMinRows = 6;
static const NSInteger kMaxRows = 10;

// How long the calendar takes to snap to a whole number of rows
// after the resize handle is let go.
static const CFTimeInterval kSnapDuration = 0.15;

@implementation MoCalendar
{
    NSDateFormatter *_formatter;
    NSTextField *_monthLabel;
    MoCalGrid *_dateGrid;
    MoCalGrid *_weekGrid;
    MoCalGrid *_dowGrid;
    MoButton *_btnPrev, *_btnNext, *_btnToday;
    NSLayoutConstraint *_weeksConstraint;
    __weak MoCalCell *_hoveredCell;
    __weak MoCalCell *_selectedCell;
    __weak MoCalCell *_monthStartCell;
    __weak MoCalCell *_monthEndCell;
    NSBezierPath *_highlightPath;
    NSColor *_highlightColor;
    MoCalResizeHandle *_resizeHandle;
    NSInteger _repeatCount;

    // While the resize handle is dragged, and then while the calendar
    // snaps to whole rows, these set the date and week grids' height.
    NSLayoutConstraint *_dateGridHeight;
    NSLayoutConstraint *_weekGridHeight;
    CADisplayLink *_snapLink;
    CFTimeInterval _snapStartTime;
    CGFloat _snapStartHeight;
    NSInteger _snapRows;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        [self commonInitForMoCalendar];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInitForMoCalendar];
    }
    return self;
}

- (void)commonInitForMoCalendar
{
    _formatter = [NSDateFormatter new];

    _monthLabel = [NSTextField labelWithString:@""];
    _monthLabel.font = [NSFont systemFontOfSize:SizePref.calendarTitleFontSize weight:NSFontWeightSemibold];
    _monthLabel.textColor = Theme.monthTextColor;
    
    // Make long labels compress and show ellipsis instead of forcing the window wider.
    // Prevent short label from pulling buttons leftward toward it.
    [_monthLabel setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_monthLabel setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [_monthLabel setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    // Convenience function to make buttons.
    MoButton* (^btn)(NSString*, SEL) = ^MoButton* (NSString *imageName, SEL action) {
        MoButton *btn = [MoButton new];
        [btn setImage:[NSImage imageNamed:imageName]];
        [btn setAlternateImage:[NSImage imageNamed:[imageName stringByAppendingString:@"Alt"]]];
        [btn setContentTintColor:Theme.buttonTintColor];
        [btn setTarget:self];
        [btn setAction:action];
        [self addSubview:btn];
        return btn;
    };
    _btnPrev  = btn(@"btnPrev",  @selector(showPreviousMonth:));
    _btnToday = btn(@"btnToday", @selector(showTodayMonth:));
    _btnNext  = btn(@"btnNext",  @selector(showNextMonth:));

    NSInteger numRows = [[NSUserDefaults standardUserDefaults] integerForKey:kMoCalendarNumRows];
    numRows = MIN(MAX(numRows, kMinRows), kMaxRows);
    
    _dateGrid = [[MoCalGrid alloc] initWithRows:numRows columns:7 horizontalMargin:6 verticalMargin:6];
    _weekGrid = [[MoCalGrid alloc] initWithRows:numRows columns:1 horizontalMargin:0 verticalMargin:6];
    _dowGrid  = [[MoCalGrid alloc] initWithRows:1 columns:7 horizontalMargin:6 verticalMargin:0];

    for (MoCalCell *cell in _dowGrid.cells) {
        cell.textField.font = [NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightSemibold];
    }

    // The _resizeHandle is at the bottom of the calendar.
    _resizeHandle = [MoCalResizeHandle new];
    [_resizeHandle dim:YES];

    [self addSubview:_monthLabel];
    [self addSubview:_dateGrid];
    [self addSubview:_weekGrid];
    [self addSubview:_dowGrid];
    [self addSubview:_resizeHandle];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_monthLabel, _btnPrev, _btnToday, _btnNext, _dowGrid, _weekGrid, _dateGrid, _resizeHandle)];
    [vfl :@"H:|-8-[_monthLabel]-4-[_btnPrev][_btnToday][_btnNext]-8-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:[_dowGrid]|"];
    [vfl :@"H:[_weekGrid]-(-2)-[_dateGrid]|"];
    [vfl :@"H:|[_resizeHandle]|"];
    [vfl :@"V:|-(-1)-[_monthLabel]-7-[_dowGrid]-(-6)-[_dateGrid]-5-|"];
    [vfl :@"V:[_weekGrid]-5-|"];
    [vfl :@"V:[_resizeHandle(8)]|"];

    _weeksConstraint = [NSLayoutConstraint constraintWithItem:_weekGrid attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:2];
    [self addConstraint:_weeksConstraint];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLocaleNotification:) name:NSCurrentLocaleDidChangeNotification object:nil];

    _weekStartDOW = 0;  // 0=Sunday, 1=Monday...
    _highlightedDOWs = DOWMaskNone;
    _showWeeks    = NO;
    _doNotDrawOutlineAroundCurrentMonth = NO;
    _monthDate    = MakeDate(1583, 0, 1);   // _monthDate must be different from the
    _selectedDate = MakeDate(1583, 0, 1);   // date set in setMonthDate:selectedDate:
    _todayDate    = MakeDate(1986, 10, 12); // so calendar will draw on first display
    [self setMonthDate:_todayDate selectedDate:_todayDate];
    
    REGISTER_FOR_SIZE_CHANGE;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:NSWindowDidChangeOcclusionStateNotification object:nil];
    if (self.window) {
        [nc addObserver:self selector:@selector(windowDidChangeOcclusionState:) name:NSWindowDidChangeOcclusionStateNotification object:self.window];
    }
}

- (void)windowDidChangeOcclusionState:(NSNotification *)notification
{
    // When the window hides, the pointer doesn't report leaving the
    // day it's over. Forget it, so resting on that day after the window
    // shows again gets its tooltip (and the day isn't left hovered).
    // (The tooltip controller hides the tooltip itself.)
    if (!(self.window.occlusionState & NSWindowOcclusionStateVisible)) {
        _hoveredCell.isHovered = NO;
        _hoveredCell = nil;
        // A drag or snap can't go on while the window is hidden. End it.
        [self finishResizing];
    }
}

#pragma mark
#pragma mark Instance methods

- (void)setMonthDate:(MoDate)monthDate
{
    if (IsValidDate(monthDate)) {
        // If the provided month is today's month, select today.
        // Otherwise, select the first of the month.
        if (self.todayDate.month == monthDate.month && self.todayDate.year == monthDate.year) {
            [self setMonthDate:monthDate selectedDate:self.todayDate];
        }
        else {
            [self setMonthDate:monthDate selectedDate:monthDate];
        }
    }
}

- (void)setSelectedDate:(MoDate)selectedDate
{
    if (IsValidDate(selectedDate)) {
        [self setMonthDate:selectedDate selectedDate:selectedDate];
    }
}

- (void)setTodayDate:(MoDate)todayDate
{
    if (IsValidDate(todayDate)) {
        _todayDate = todayDate;
        for (MoCalCell *c in _dateGrid.cells) {
            c.isToday = CompareDates(c.date, todayDate) == 0;
        }
    }
}

- (MoDate)firstDate
{
    return _dateGrid.cells.firstObject.date;
}

- (MoDate)lastDate
{
    return _dateGrid.cells.lastObject.date;
}

- (void)setWeekStartDOW:(NSInteger)weekStartDOW
{
    if (weekStartDOW < 0 || weekStartDOW > 6) {
        return;
    }
    if (_weekStartDOW != weekStartDOW) {
        _weekStartDOW = weekStartDOW;
        [self updateCalendar];
        // Now that the calendar has been redrawn with a new
        // weekStartDOW, selectedDate and selectedCell are out of
        // sync. So we need to resync them.
        // If the cell for selectedDate is still visible, then use
        // that cell as selectedCell. Otherwise, keep selectedCell
        // where it is and use its date as selectedDate.
        MoCalCell *cell = [_dateGrid cellWithDate:self.selectedDate];
        if (cell) {
            _selectedCell.isSelected = NO;
            _selectedCell = cell;
            _selectedCell.isSelected = YES;
        }
        else {
            _selectedDate = _selectedCell.date;
        }
    }
}

- (void)setShowWeeks:(BOOL)showWeeks
{
    _showWeeks = showWeeks;
    CGFloat constant = showWeeks ? NSWidth(_weekGrid.frame) : 2;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
        [ctx setDuration:0.1];
        [self->_weeksConstraint.animator setConstant:constant];
    } completionHandler:NULL];
}

- (void)setShowEventDots:(BOOL)showEventDots
{
    _showEventDots = showEventDots;
    [self reloadData];
}

- (void)setUseColoredDots:(BOOL)useColoredDots
{
    _useColoredDots = useColoredDots;
    [self reloadData];
}

- (void)setHighlightedDOWs:(DOWMask)highlightedDOWs
{
    _highlightedDOWs = highlightedDOWs;
    [self updateCalendar];
}

- (void)setDoNotDrawOutlineAroundCurrentMonth:(BOOL)doNotDrawOutlineAroundCurrentMonth
{
    _doNotDrawOutlineAroundCurrentMonth = doNotDrawOutlineAroundCurrentMonth;
    [self setNeedsDisplay:YES];
}

- (void)setTooltipController:(TooltipController *)tooltipController
{
    _tooltipController = tooltipController;
    // The buttons' shortcuts are handled in -keyDown:, not as the
    // buttons' key equivalents, so give the badges' text.
    [tooltipController addTooltipToView:_btnPrev label:^NSString *{
        return NSLocalizedString(@"Previous Month", @"Tooltip for the calendar's button that shows the previous month");
    } shortcut:@"←"];
    [tooltipController addTooltipToView:_btnToday label:^NSString *{
        return NSLocalizedString(@"Today", @"Tooltip for the calendar's button that shows today");
    } shortcut:NSLocalizedString(@"Space", @"The space bar's name in a tooltip's keyboard shortcut, e.g. the Today button's")];
    [tooltipController addTooltipToView:_btnNext label:^NSString *{
        return NSLocalizedString(@"Next Month", @"Tooltip for the calendar's button that shows the next month");
    } shortcut:@"→"];
}

- (IBAction)showPreviousMonth:(id)sender
{
    self.monthDate = AddMonthsToMonth(-1, self.monthDate);
}

- (IBAction)showNextMonth:(id)sender
{
    self.monthDate = AddMonthsToMonth(1, self.monthDate);
}

- (IBAction)showTodayMonth:(id)sender
{
    [self setMonthDate:self.todayDate selectedDate:self.todayDate];
    // If the day has changed, we must update the calendar.
    if (CompareDates(self.todayDate, _selectedCell.date) != 0) {
        [self updateCalendar];
    }
}

- (void)updateCalendar
{
    // Month/year and DOW labels
    NSArray *dows = [_formatter veryShortWeekdaySymbols];
    [_monthLabel setStringValue:[self monthTitle]];
    // Make French dow strings lowercase because that is the convention
    // in France. -veryShortWeekdaySymbols should have done this for us.
    if ([[NSLocale currentLocale].localeIdentifier hasPrefix:@"fr"]) {
        dows = @[@"d", @"l", @"m", @"m", @"j", @"v", @"s"];
    }
    // macOS gives the English veryShortWeekdaySymbols for Esperanto.
    else if ([[NSLocale currentLocale].localeIdentifier hasPrefix:@"eo"]) {
        dows = @[@"D", @"L", @"M", @"M", @"Ĵ", @"V", @"S"];
    }
    for (NSInteger col = 0; col < 7; col++) {
        NSString *dow = [NSString stringWithFormat:@"%@", dows[COL_DOW(self.weekStartDOW, col)]];
        [[_dowGrid.cells[col] textField] setStringValue:dow];
        [[_dowGrid.cells[col] textField] setTextColor:[self columnIsMemberOfHighlightedDOWs:col] 
         ? Theme.highlightedDOWTextColor
         : Theme.DOWTextColor];
    }
    
    // The first date shown, to tell whether the dates change.
    MoDate oldFirstDate = self.firstDate;

    // Get the first of the month.
    MoDate firstOfMonth = MakeDate(self.monthDate.year, self.monthDate.month, 1);
    
    // Get the DOW for the first of the month.
    // en.wikipedia.org/wiki/Julian_day#Finding_day_of_week_given_Julian_day_number
    NSInteger monthStartDOW = (firstOfMonth.julian + 1)%7;
    
    // On which column [0..6] in the monthly calendar does this date fall?
    NSInteger monthStartColumn = DOW_COL(self.weekStartDOW, monthStartDOW);
    
    // Get the date for the first column of the monthly calendar.
    MoDate date = AddDaysToDate(-monthStartColumn, firstOfMonth);
    
    // Fill in the calendar grid sequentially.
    for (NSInteger row = 0; row < _dateGrid.rows; row++) {
        for (NSInteger col = 0; col < 7; col++) {
            MoCalCell *cell = _dateGrid.cells[row * 7 + col];
            cell.textField.integerValue = date.day;
            cell.date = date;
            cell.isToday = CompareDates(date, self.todayDate) == 0;
            cell.isHighlighted = [self columnIsMemberOfHighlightedDOWs:col];
            cell.isInCurrentMonth = (date.month == self.monthDate.month);
            if (date.month == self.monthDate.month) {
                if (date.day == 1) {
                    _monthStartCell = cell;
                }
                else if (date.day == DaysInMonth(date.year, date.month)) {
                    _monthEndCell = cell;
                }
            }
            // ISO 8601 weeks are defined to start on Monday (and
            // really only make sense if self.weekStartDOW is Monday).
            // If the current column is Monday, use this date to
            // calculate the week number for this row.
            if (col == DOW_COL(self.weekStartDOW, 1)) {
                [_weekGrid.cells[row] textField].textColor = Theme.weekTextColor;
                [_weekGrid.cells[row] textField].integerValue = WeekOfYear(date.year, date.month, date.day);
            }
            date = AddDaysToDate(1, date);
        }
    }
    [self setNeedsDisplay:YES];

    // The day under the pointer is now a different day: hide its
    // tooltip, and start the delay for the new day's.
    if (CompareDates(oldFirstDate, self.firstDate) != 0) {
        [self.tooltipController hideImmediately];
        if (_hoveredCell) {
            [self pointerEnteredCellForTooltip:_hoveredCell];
        }
    }

    [self.delegate calendarUpdated:self];
}

- (void)reloadData
{
    for (MoCalCell *c in _dateGrid.cells) {
        c.dotColors = self.showEventDots
            ? [self.delegate dotColorsForDate:c.date useColor:self.useColoredDots]
            : nil;
    }
    // The events changed.
    [self.tooltipController reloadContent];
}

- (void)highlightCellsFromDate:(MoDate)startDate toDate:(MoDate)endDate withColor:(NSColor *)color
{
    MoCalCell *startCell=nil, *endCell=nil;
    for (MoCalCell *cell in _dateGrid.cells) {
        if (!startCell && CompareDates(startDate, cell.date) <= 0) {
            startCell = cell;
        }
        if (CompareDates(endDate, cell.date) >= 0) {
            endCell = cell;
        }
    }
    if (startCell && endCell) {
        CGFloat radius = SizePref.cellRadius;
        _highlightPath = [self bezierPathWithStartCell:startCell endCell:endCell radius:radius inset:3 useRects:YES];
        _highlightColor = color;
        // Normalize location of _highlightPath. We will tranlsate it
        // again in drawRect to the correct location.
        NSAffineTransform *t = [NSAffineTransform new];
        [t translateXBy:-NSMinX(_dateGrid.frame) yBy:0];
        [_highlightPath transformUsingAffineTransform:t];
        [self setNeedsDisplay:YES];
    }
}

- (void)unhighlightCells
{
    _highlightPath = nil;
    _highlightColor = nil;
    [self setNeedsDisplay:YES];
}

- (void)sizeChanged:(id)sender
{
    _monthLabel.font = [NSFont systemFontOfSize:SizePref.calendarTitleFontSize weight:NSFontWeightSemibold];
    _weeksConstraint.constant = self.showWeeks ? SizePref.cellSize : 2;
}

#pragma mark -
#pragma mark Process input

- (void)keyDown:(NSEvent *)theEvent
{
    NSString *charsIgnoringModifiers = [theEvent charactersIgnoringModifiers];
    if (charsIgnoringModifiers.length != 1) return;
    
    NSUInteger flags = [theEvent modifierFlags];
    BOOL noFlags =  !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl | NSEventModifierFlagShift));
    BOOL shiftFlag = (flags &  NSEventModifierFlagShift) && !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl));
    BOOL ctrlFlag = (flags &  NSEventModifierFlagControl) && !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagShift));

    unichar keyChar = [charsIgnoringModifiers characterAtIndex:0];
    
    if (keyChar == ' ') {
        [_btnToday performClick:self];
    }
    else if ((keyChar == 'H' && shiftFlag) || (keyChar == NSLeftArrowFunctionKey && noFlags)) {
        NSInteger n = [self repeatCountify:-1];
        if (n < -1) {
            self.monthDate = AddMonthsToMonth(n, self.monthDate);
        } else {
            [_btnPrev performClick:self];
        }
    }
    else if ((keyChar == 'L' && shiftFlag) || (keyChar == NSRightArrowFunctionKey && noFlags)) {
        NSInteger n = [self repeatCountify:1];
        if (n > 1) {
            self.monthDate = AddMonthsToMonth(n, self.monthDate);
        } else {
            [_btnNext performClick:self];
        }
    }
    else if ((keyChar == 'J' && shiftFlag) || (keyChar == NSDownArrowFunctionKey && noFlags)) {
        NSInteger n = [self repeatCountify:12];
        self.monthDate = AddMonthsToMonth(n, self.monthDate);
    }
    else if ((keyChar == 'K' && shiftFlag) || (keyChar == NSUpArrowFunctionKey && noFlags)) {
        NSInteger n = [self repeatCountify:-12];
        self.monthDate = AddMonthsToMonth(n, self.monthDate);
    }
    else if ((keyChar == 'h' && noFlags) || (keyChar == NSLeftArrowFunctionKey && shiftFlag)) {
        NSInteger n = [self repeatCountify:-1];
        [self moveSelectionByDays:n];
    }
    else if ((keyChar == 'l' && noFlags) || (keyChar == NSRightArrowFunctionKey && shiftFlag)) {
        NSInteger n = [self repeatCountify:1];
        [self moveSelectionByDays:n];
    }
    else if ((keyChar == 'j' && noFlags) || (keyChar == NSDownArrowFunctionKey && shiftFlag)) {
        NSInteger n = [self repeatCountify:7];
        [self moveSelectionByDays:n];
    }
    else if ((keyChar == 'k' && noFlags) || (keyChar == NSUpArrowFunctionKey && shiftFlag)) {
        NSInteger n = [self repeatCountify:-7];
        [self moveSelectionByDays:n];
    }
    else if (keyChar == 'j' && ctrlFlag) {
        [self addRow];
    }
    else if (keyChar == 'k' && ctrlFlag) {
        [self removeRow];
    }
    else if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:keyChar] && noFlags) {
        [self repeatCountUpdate:keyChar];
    }
    else if ([theEvent.characters hasPrefix:@"#"]) {
        [self showDateInfo];
    }
    else {
        [super keyDown:theEvent];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    if (NSPointInRect(location, _resizeHandle.frame)) {
        [self dragResizeHandle];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if ([theEvent clickCount] == 1) {
        NSPoint locationInWindow = [theEvent locationInWindow];
        NSPoint locationInDates  = [_dateGrid convertPoint:locationInWindow fromView:nil];
        MoCalCell *clickedCell   = [_dateGrid cellAtPoint:locationInDates];
        if (clickedCell && clickedCell != _selectedCell) {
            [self setMonthDate:self.monthDate selectedDate:clickedCell.date];
        }
    }
    else if ([theEvent clickCount] == 2) {
        if (self.target && self.doubleAction) {
            [NSApp sendAction:self.doubleAction to:self.target from:self];
        }
    }
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    if (!self.window.isVisible) {
        // On macOS 10.14, -mouseMoved: can be called even when the
        // calendar (and its window) are *not visible* under certain
        // circumstances. This leads to tooltips mysteriously popping
        // up out of nowhere when the user's mouse is where Itsycal's
        // window *would be* if it were actually showing. By updating
        // the tracking areas, -mouseMoved: is no longer erroneously
        // called.
        [self updateTrackingAreas];
        return;
    }
    NSPoint locationInWindow = [theEvent locationInWindow];
    NSPoint locationInDates  = [_dateGrid convertPoint:locationInWindow fromView:nil];
    MoCalCell *hoveredCell   = [_dateGrid cellAtPoint:locationInDates];
    if (hoveredCell && hoveredCell != _hoveredCell) {
        if (_hoveredCell) {
            [self.tooltipController pointerExitedTarget:_hoveredCell];
        }
        _hoveredCell.isHovered = NO;
        _hoveredCell = hoveredCell;
        _hoveredCell.isHovered = YES;
        [self pointerEnteredCellForTooltip:_hoveredCell];
    }
}

- (void)pointerEnteredCellForTooltip:(MoCalCell *)cell
{
    // The day is a target only if it has events.
    MoDate date = cell.date;
    __weak typeof(self) weakSelf = self;
    [self.tooltipController pointerEnteredTarget:cell content:^id<TooltipContent>{
        return [weakSelf.delegate tooltipContentForDate:date];
    }];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    if ([[(NSDictionary *)[theEvent userData] valueForKey:@"area"] isEqualToString: @"resizeHandle"]) {
        [_resizeHandle dim:NO];
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    if ([[(NSDictionary *)[theEvent userData] valueForKey:@"area"] isEqualToString: @"resizeHandle"]) {
        [_resizeHandle dim:YES];
    }
    else { // userData[area] == "dateGrid"
        if (_hoveredCell) {
            [self.tooltipController pointerExitedTarget:_hoveredCell];
        }
        _hoveredCell.isHovered = NO;
        _hoveredCell = nil;
        [self setNeedsDisplay:YES];
    }
}

- (void)updateTrackingAreas
{
    for (NSTrackingArea *area in self.trackingAreas) {
        [self removeTrackingArea:area];
    }
    // cellsRect encompasses the cells in _dateGrid (not including their margins)
    NSRect cellsRect = [self convertRect:[_dateGrid cellsRect] fromView:_dateGrid];
    NSTrackingArea *cellsTrackingArea = [[NSTrackingArea alloc] initWithRect:cellsRect options:(NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"area": @"dateGrid"}];

    NSTrackingArea *resizeHandleTrackingArea = [[NSTrackingArea alloc] initWithRect:_resizeHandle.frame options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"area": @"resizeHandle"}];

    [self addTrackingArea:cellsTrackingArea];
    [self addTrackingArea:resizeHandleTrackingArea];
    [super updateTrackingAreas];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // Left/right swipes change to previous/next months.
    if (theEvent.phase == NSEventPhaseBegan) {
        CGFloat dX = theEvent.scrollingDeltaX;
        if (dX != 0) {
            [theEvent trackSwipeEventWithOptions:(NSEventSwipeTrackingLockDirection) dampenAmountThresholdMin:-1 max:1 usingHandler:^(CGFloat amount, NSEventPhase phase, BOOL isDone, BOOL *stop) {
                if (phase == NSEventPhaseEnded) {
                    if (dX < 0) {
                        [self showNextMonth:nil];
                    }
                    else {
                        [self showPreviousMonth:nil];
                    }
                }
            }];
        }
    }
    [super scrollWheel:theEvent];
}

#pragma mark
#pragma mark Repeat count

- (void)repeatCountUpdate:(unichar)keyChar
{
    // Is there a better way to convert unichar to NSInteger?
    NSInteger n = (NSInteger)keyChar - 48;
    if (_repeatCount < 100) { // max _repeatCount allowed is 999
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatCountClear) object:nil];
        _repeatCount = _repeatCount*10 + n;
        [self performSelector:@selector(repeatCountClear) withObject:nil afterDelay:3];
    }
}

- (void)repeatCountClear
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatCountClear) object:nil];
    _repeatCount = 0;
}

- (NSInteger)repeatCountify:(NSInteger)n
{
    NSInteger result = (_repeatCount > 0) ? n * _repeatCount : n;
    [self repeatCountClear];
    return result;
}

#pragma mark
#pragma mark Day info

- (void)showDateInfo
{
    static NSNumberFormatter *groupingFormatter = nil;
    if (!groupingFormatter) {
        groupingFormatter = [NSNumberFormatter new];
        groupingFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        groupingFormatter.groupingSeparator = [NSLocale.currentLocale objectForKey:NSLocaleGroupingSeparator];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearDateInfo) object:nil];
    // Get selectedDate's offset from today.
    NSInteger dayDiff = CompareDates(self.selectedDate, self.todayDate);
    NSString *dayInfo = [groupingFormatter stringFromNumber:@(labs(dayDiff))];
    dayInfo = (dayDiff >= 0)?
        [@"+" stringByAppendingString:dayInfo]:
        [@"−" stringByAppendingString:dayInfo];
    // Get day of the year.
    MoDate firstOfYear = MakeDate(self.selectedDate.year, 0, 1);
    NSInteger dayOfYear = CompareDates(self.selectedDate, firstOfYear) + 1;
    dayInfo = [NSString stringWithFormat:@"%@ ∕ %zd", dayInfo, dayOfYear];
    [_monthLabel setStringValue:dayInfo];
    [self performSelector:@selector(clearDateInfo) withObject:nil afterDelay:2];
}

- (void)clearDateInfo
{
    [_monthLabel setStringValue:[self monthTitle]];
}

#pragma mark
#pragma mark Utilities

- (NSString *)monthTitle
{
    NSArray *months = [_formatter shortMonthSymbols];
    NSString *title = [NSString stringWithFormat:@"%@ %zd", months[self.monthDate.month], self.monthDate.year];
#ifdef DEBUG
    // Mark debug builds so they're easy to tell apart from release builds.
    title = [title stringByAppendingString:@" ✱"];
#endif
    return title;
}

- (void)setMonthDate:(MoDate)monthDate selectedDate:(MoDate)selectedDate
{
    // This method is where the instance variables backing the
    // monthDate and selectedDate properties are set.
    
    BOOL didChangeMonth = NO;
    
    monthDate = MakeDate(monthDate.year, monthDate.month, 1);
    
    if (CompareDates(monthDate, self.monthDate) != 0) {
        _monthDate = monthDate;
        [self updateCalendar];
        didChangeMonth = YES;
    }
    if (didChangeMonth == YES || CompareDates(selectedDate, self.selectedDate) != 0) {
        _selectedDate = selectedDate;
        _selectedCell.isSelected = NO;
        _selectedCell = [_dateGrid cellWithDate:selectedDate];
        _selectedCell.isSelected = YES;
        [self setNeedsDisplay:YES];
        [self.delegate calendarSelectionChanged:self];
    }
}

- (void)moveSelectionByDays:(NSInteger)days
{
    MoDate newSelectedDate = AddDaysToDate(days, self.selectedDate);
    MoDate firstCellDate = [_dateGrid.cells.firstObject date];
    MoDate lastCellDate  = [_dateGrid.cells.lastObject date];
    if (CompareDates(newSelectedDate, firstCellDate) < 0 ||
        CompareDates(newSelectedDate, lastCellDate ) > 0) {
        [self setMonthDate:newSelectedDate selectedDate:newSelectedDate];
    }
    else {
        [self setMonthDate:self.monthDate selectedDate:newSelectedDate];
    }
}

- (void)handleLocaleNotification:(NSNotification *)notification
{
    // Redraw calendar with locale-specific month and DOW headers
    [self updateCalendar];
}

// Helper function to determine if a given column in the
// calendar grid is a member of self.highlightedDOWs.
- (BOOL)columnIsMemberOfHighlightedDOWs:(NSInteger)col
{
    DOWMask dowmask_for_this_col = 1 << COL_DOW(self.weekStartDOW, col);
    return dowmask_for_this_col & self.highlightedDOWs;
}

- (void)addRow
{
    [self finishResizing];
    [self setNumRows:_dateGrid.rows + 1 save:YES];
}

- (void)removeRow
{
    [self finishResizing];
    [self setNumRows:_dateGrid.rows - 1 save:YES];
}

- (void)setNumRows:(NSInteger)rows save:(BOOL)save
{
    rows = MIN(MAX(rows, kMinRows), kMaxRows);
    if (rows != _dateGrid.rows) {
        while (_dateGrid.rows > rows) {
            // Move selection up one row (-7 days) if it is
            // in the row that is about to be removed.
            NSUInteger selectedCellIndex = [_dateGrid.cells indexOfObject:_selectedCell];
            if (selectedCellIndex != NSNotFound && selectedCellIndex >= _dateGrid.cells.count - 7) {
                [self moveSelectionByDays:-7];
            }
            [_dateGrid removeRow];
            [_weekGrid removeRow];
        }
        while (_dateGrid.rows < rows) {
            [_dateGrid addRow];
            [_weekGrid addRow];
        }
        [self updateCalendar];
    }
    if (save) {
        [[NSUserDefaults standardUserDefaults] setInteger:rows forKey:kMoCalendarNumRows];
    }
}

#pragma mark
#pragma mark Resize handle

- (void)dragResizeHandle
{
    // The calendar follows the pointer: its grids are as tall as the
    // drag makes them, with at least enough rows to fill them; the rows
    // that don't fit are cut off. (The window resizes to fit.) When the
    // handle is let go, the calendar snaps to the nearest whole row.
    // The week grid's rows match the date grid's, so it gets the date
    // grid's heights.
    [self.tooltipController hideImmediately];
    [_resizeHandle dim:NO];

    CGFloat startHeight;
    if (_dateGridHeight) {
        // The calendar is snapping from the last drag. Stop and
        // continue from where it is, which is under the pointer.
        [_snapLink invalidate];
        _snapLink = nil;
        startHeight = _dateGridHeight.constant;
    }
    else {
        startHeight = [_dateGrid heightForRows:_dateGrid.rows];
        _dateGridHeight = [_dateGrid.heightAnchor constraintEqualToConstant:startHeight];
        _weekGridHeight = [_weekGrid.heightAnchor constraintEqualToConstant:startHeight];
        _dateGridHeight.active = YES;
        _weekGridHeight.active = YES;
        // If the drag is cut short (see -finishResizing), keep the rows.
        // (A drag that takes over a snap keeps the snap's rows instead.)
        _snapRows = _dateGrid.rows;
    }

    // Use the pointer's location on the screen: the window
    // moves in the screen as it resizes, so its coordinates do too.
    CGFloat startY = [NSEvent mouseLocation].y;
    CGFloat minHeight = [_dateGrid heightForRows:kMinRows];
    CGFloat maxHeight = [_dateGrid heightForRows:kMaxRows];
    CGFloat height = startHeight;
    // The loop ends early if the window hides (see -finishResizing).
    while (_dateGridHeight) {
        NSEvent *event = [self.window nextEventMatchingMask:NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
        if (event.type == NSEventTypeLeftMouseUp) {
            break;
        }
        // Whole points keep the cells on whole points, which
        // -bezierPathWithStartCell:... needs to step through rows.
        height = round(startHeight + startY - [NSEvent mouseLocation].y);
        height = MIN(MAX(height, minHeight), maxHeight);
        [self setGridHeight:height];
    }
    if (!_dateGridHeight) {
        return; // The window hid during the drag.
    }

    _snapRows = MIN(MAX(lround([_dateGrid rowsForHeight:height]), kMinRows), kMaxRows);
    _snapStartHeight = height;
    _snapStartTime = CACurrentMediaTime();
    _snapLink = [self displayLinkWithTarget:self selector:@selector(snapStep:)];
    [_snapLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)setGridHeight:(CGFloat)height
{
    if (!_dateGridHeight) {
        return; // -finishResizing ended the resize.
    }
    _dateGridHeight.constant = height;
    _weekGridHeight.constant = height;
    // Add rows to fill the height. (Allow for rounding so a height of
    // exactly n rows doesn't need n + 1.) Don't remove rows: the extra
    // ones are cut off, and -finishResizing removes them. So a row that
    // a drag hides and shows again doesn't move the selection, which
    // removing the selected day's row does.
    NSInteger rows = ceil([_dateGrid rowsForHeight:height] - 0.001);
    if (rows > (NSInteger)_dateGrid.rows) {
        [self setNumRows:rows save:NO];
    }
}

- (void)snapStep:(CADisplayLink *)link
{
    CGFloat t = (CACurrentMediaTime() - _snapStartTime) / kSnapDuration;
    if (t >= 1) {
        [self finishResizing];
        return;
    }
    CGFloat eased = 1 - pow(1 - t, 3); // ease out
    CGFloat endHeight = [_dateGrid heightForRows:_snapRows];
    [self setGridHeight:round(_snapStartHeight + (endHeight - _snapStartHeight) * eased)];
}

// End a resize-handle drag's snap, if one is in progress, at
// the number of rows it's snapping to, and save that number.
- (void)finishResizing
{
    [_snapLink invalidate];
    _snapLink = nil;
    if (!_dateGridHeight) {
        return;
    }
    _dateGridHeight.active = NO;
    _weekGridHeight.active = NO;
    _dateGridHeight = nil;
    _weekGridHeight = nil;
    [self setNumRows:_snapRows save:YES];

    // The snap may have moved the handle out from under the pointer,
    // which -mouseExited: won't catch, so dim the handle if it did.
    [self.window layoutIfNeeded];
    NSPoint location = [self convertPoint:self.window.mouseLocationOutsideOfEventStream fromView:nil];
    [_resizeHandle dim:!NSPointInRect(location, _resizeHandle.frame)];
}

#pragma mark
#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect
{
    [Theme.mainBackgroundColor set];
    NSRectFill(self.bounds);
    
    CGFloat radius = SizePref.cellRadius + 3;
    CGFloat sz = SizePref.cellSize;
    if (self.highlightedDOWs) {
        NSRect weekendRect = [self convertRect:[_dateGrid cellsRect] fromView:_dateGrid];
        weekendRect.size.width = sz;
        [Theme.highlightedDOWBackgroundColor set];
        NSInteger numColsToHighlight = 0;
        for (NSInteger col = 0; col <= 7; col++) {
            if (col < 7 && [self columnIsMemberOfHighlightedDOWs:col]) {
                numColsToHighlight++;
            }
            else {
                if (numColsToHighlight) {
                    NSInteger startCol = col - numColsToHighlight;
                    NSRect rect = NSOffsetRect(weekendRect, startCol * sz, 0);
                    rect.size.width *= numColsToHighlight;
                    [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius] fill];
                }
                numColsToHighlight = 0;
            }
        }
    }

    if (_highlightPath) {
        // Tranlsate the highlight path. It's location will depend
        // on whether we are showing weeks or not because they add
        // an additional column.
        NSAffineTransform *t = [NSAffineTransform new];
        [t translateXBy:NSMinX(_dateGrid.frame) yBy:0];
        NSBezierPath *highlightPath = [_highlightPath copy];
        [highlightPath transformUsingAffineTransform:t];
        [[_highlightColor colorWithAlphaComponent:0.36] setFill];
        [highlightPath fill];
    }

    if (!self.doNotDrawOutlineAroundCurrentMonth) {
        NSBezierPath *outlinePath = [self bezierPathWithStartCell:_monthStartCell endCell:_monthEndCell radius:radius inset:0 useRects:NO];

        [Theme.currentMonthOutlineColor set];
        [outlinePath setLineWidth:1.5];
        [outlinePath stroke];
    }
}

- (NSBezierPath *)bezierPathWithStartCell:(MoCalCell *)startCell endCell:(MoCalCell *)endCell radius:(CGFloat)r inset:(CGFloat)inset useRects:(BOOL)useRects
{
    // Create a bezier path around the range of cells specified by
    // startCell and endCell. The path has rounded corners specified
    // by radius r. If useRects == YES, the path is composed only of
    // horizontal rounded rects. Otherwise, the path is a region.
    
    // First get the frame rects of the start and end cells in self view coordinates.
    
    NSRect startRect = [self convertRect:startCell.bounds fromView:startCell];
    NSRect endRect   = [self convertRect:endCell.bounds fromView:endCell];
    startRect = NSInsetRect(startRect, inset, inset);
    endRect   = NSInsetRect(endRect, inset, inset);
    
    // Get the left and right edges of the path in self view coordinates.

    NSRect dateCellsRect = [self convertRect:[_dateGrid cellsRect] fromView:_dateGrid];
    CGFloat leftEdge  = NSMinX(NSInsetRect(dateCellsRect, inset, inset));
    CGFloat rightEdge = NSMaxX(NSInsetRect(dateCellsRect, inset, inset));
    
    // Now that we have the rects, create the path...
    
    CGFloat x = startRect.origin.x;
    CGFloat y = startRect.origin.y;
    
    NSBezierPath *p;
    
    // Case 1: startRect and endRect are on the same row.
    
    if (NSMinY(startRect) == NSMinY(endRect)) {
        p = [NSBezierPath bezierPathWithRoundedRect:NSUnionRect(startRect, endRect) xRadius:r yRadius:r];
    }
    
    // Case 2: startRect and endRect are on adjacent rows with no
    // vertical overlap -OR- we must use rects to build the path.
    
    else if (((NSMinY(startRect) - inset == NSMinY(endRect) + NSHeight(endRect) + inset) &&
              (NSMinX(startRect) > NSMinX(endRect))) ||
             useRects) {
        NSRect rect = NSMakeRect(x, y, rightEdge - x, NSHeight(startRect));
        p = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r];
        CGFloat yStep = 2 * inset + NSHeight(startRect);
        for (y = y - yStep; y != NSMinY(endRect); y -= yStep) {
            rect = NSMakeRect(leftEdge, y, rightEdge - leftEdge, NSHeight(startRect));
            [p appendBezierPathWithRoundedRect:rect xRadius:r yRadius:r];
        }
        x = endRect.origin.x;
        y = endRect.origin.y;
        rect = NSMakeRect(leftEdge, y, x - leftEdge + NSWidth(endRect), NSHeight(endRect));
        [p appendBezierPathWithRoundedRect:rect xRadius:r yRadius:r];
    }
    
    // Case 3: startRect and endRect have at least one row
    // between them and/or overlap vertically.
    
    else {
        p = [NSBezierPath bezierPath];
        [p moveToPoint:NSMakePoint(x, y + r)];
        y = NSMaxY(startRect);
        [p lineToPoint:NSMakePoint(x, y - r)];
        [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x + r, y) radius:r];
        x = rightEdge;
        [p lineToPoint:NSMakePoint(x - r, y)];
        [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x, y - r) radius:r];
        if (NSMaxX(endRect) != rightEdge) {
            y = NSMaxY(endRect) + 2 * inset;
            [p lineToPoint:NSMakePoint(x, y + r)];
            [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x - r, y) radius:r];
            x = NSMaxX(endRect);
            [p lineToPoint:NSMakePoint(x + r, y)];
            [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x, y - r) radius:r];
        }
        y = NSMinY(endRect);
        [p lineToPoint:NSMakePoint(x, y + r)];
        [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x - r, y) radius:r];
        x = leftEdge;
        [p lineToPoint:NSMakePoint(x + r, y)];
        [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x, y + r) radius:r];
        if (NSMinX(startRect) != leftEdge) {
            y = NSMinY(startRect) - 2 * inset;
            [p lineToPoint:NSMakePoint(x, y - r)];
            [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x + r, y) radius:r];
            x = NSMinX(startRect);
            [p lineToPoint:NSMakePoint(x - r, y)];
            [p appendBezierPathWithArcFromPoint:NSMakePoint(x, y) toPoint:NSMakePoint(x, y + r) radius:r];
        }
        [p closePath];
    }
    return p;
}

@end
