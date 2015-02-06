//
//  MoCalendar.m
//
//
//  Created by Sanjay Madan on 11/13/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoCalendar.h"
#import "MoCalCell.h"
#import "MoCalGrid.h"

static NSShadow *kShadow=nil;
static NSColor *kBackgroundColor=nil, *kWeeksBackgroundColor=nil, *kDatesBackgroundColor=nil, *kOutlineColor=nil, *kLightTextColor=nil, *kDarkTextColor=nil;

@implementation MoCalendar
{
    NSDateFormatter *_formatter;
    NSTextField *_monthLabel;
    MoCalGrid *_dateGrid;
    MoCalGrid *_weekGrid;
    MoCalGrid *_dowGrid;
    NSLayoutConstraint *_weeksConstraint;
    NSButton *_btnPrev;
    NSButton *_btnNext;
    NSButton *_btnToday;
    NSTrackingArea *_trackingArea;
    __weak MoCalCell *_hoveredCell;
    __weak MoCalCell *_selectedCell;
    __weak MoCalCell *_monthStartCell;
    __weak MoCalCell *_monthEndCell;
    NSBezierPath *_highlightPath;
    NSColor *_highlightColor;
}

+ (void)initialize
{
    kShadow = [NSShadow new];
    kShadow.shadowColor = [NSColor colorWithDeviceWhite:0 alpha:0.3];
    kShadow.shadowBlurRadius = 2;
    kShadow.shadowOffset = NSMakeSize(0, -1);
    kOutlineColor = [NSColor colorWithCalibratedRed:0.7 green:0.7 blue:0.73 alpha:1];
    kLightTextColor = [NSColor colorWithCalibratedWhite:0.33 alpha:1];
    kDarkTextColor  = [NSColor colorWithCalibratedWhite:0.15 alpha:1];
    kBackgroundColor = [NSColor whiteColor];
    kWeeksBackgroundColor = [NSColor colorWithCalibratedRed:0.86 green:0.86 blue:0.88 alpha:1];
    kDatesBackgroundColor = [NSColor colorWithCalibratedRed:0.93 green:0.93 blue:0.95 alpha:1];
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
    
    _monthLabel = [NSTextField new];
    [_monthLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_monthLabel setFont:[NSFont fontWithName:@"VarelaRoundNeo-Bold" size:13]];
    [_monthLabel setTextColor:kDarkTextColor];
    [_monthLabel setBezeled:NO];
    [_monthLabel setEditable:NO];
    [_monthLabel setDrawsBackground:NO];
    
    // Make long labels compress and show ellipsis instead of forcing the window wider.
    // Prevent short label from pulling buttons leftward toward it.
    [_monthLabel setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_monthLabel setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [_monthLabel setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    // Convenience function to make buttons.
    NSButton* (^btn)(NSString*, SEL) = ^NSButton* (NSString *imageName, SEL action) {
        NSButton *btn = [NSButton new];
        [btn setButtonType:NSMomentaryChangeButton];
        [btn setBordered:NO];
        [btn setImage:[NSImage imageNamed:imageName]];
        [btn setAlternateImage:[NSImage imageNamed:[imageName stringByAppendingString:@"Alt"]]];
        [btn setTarget:self];
        [btn setAction:action];
        [btn setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:btn];
        return btn;
    };
    _btnPrev  = btn(@"btnPrev",  @selector(showPreviousMonth:));
    _btnToday = btn(@"btnToday", @selector(showTodayMonth:));
    _btnNext  = btn(@"btnNext",  @selector(showNextMonth:));
    
    _dateGrid = [[MoCalGrid alloc] initWithRows:6 columns:7 horizontalMargin:6 verticalMargin:6];
    _weekGrid = [[MoCalGrid alloc] initWithRows:6 columns:1 horizontalMargin:0 verticalMargin:6];
    _dowGrid  = [[MoCalGrid alloc] initWithRows:1 columns:7 horizontalMargin:6 verticalMargin:0];
    
    [self addSubview:_monthLabel];
    [self addSubview:_dateGrid];
    [self addSubview:_weekGrid];
    [self addSubview:_dowGrid];
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*, NSLayoutFormatOptions) = ^(NSString *format, NSLayoutFormatOptions opts) {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:opts metrics:nil views:NSDictionaryOfVariableBindings(_monthLabel, _btnPrev, _btnToday, _btnNext, _dowGrid, _weekGrid, _dateGrid)]];
    };
    vcon(@"H:|-(8)-[_monthLabel]-(4)-[_btnPrev]-(2)-[_btnToday]-(2)-[_btnNext]-(6)-|", NSLayoutFormatAlignAllCenterY);
    vcon(@"H:[_dowGrid]|", 0);
    vcon(@"H:[_weekGrid][_dateGrid]|", 0);
    vcon(@"V:|-(-3)-[_monthLabel]-(4)-[_dowGrid][_dateGrid]-(1)-|", 0);
    vcon(@"V:[_weekGrid]-(1)-|", 0);
    
    _weeksConstraint = [NSLayoutConstraint constraintWithItem:_weekGrid attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
    [self addConstraint:_weeksConstraint];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLocaleNotification:) name:NSCurrentLocaleDidChangeNotification object:nil];

    _weekStartDOW = 0;  // 0=Sunday, 1=Monday...
    _showWeeks    = NO;
    _monthDate    = MakeDate(1583, 0, 1);   // _monthDate must be different from the
    _selectedDate = MakeDate(1583, 0, 1);   // date set in setMonthDate:selectedDate:
    _todayDate    = MakeDate(1986, 10, 12); // so calendar will draw on first display
    [self setMonthDate:_todayDate selectedDate:_todayDate];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isOpaque
{
    return YES;
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
    CGFloat constant = showWeeks ? NSWidth(_weekGrid.frame) : 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
        [ctx setDuration:0.1];
        [_weeksConstraint.animator setConstant:constant];
    } completionHandler:NULL];
}

- (IBAction)showPreviousMonth:(id)sender
{
    self.monthDate = AddMonthsToMonth(-1, self.monthDate);
}

- (IBAction)showNextMonth:(id)sender
{
    self.monthDate = AddMonthsToMonth(1, self.monthDate);
}

- (IBAction)showPreviousYear:(id)sender
{
    self.monthDate = AddMonthsToMonth(-12, self.monthDate);
}

- (IBAction)showNextYear:(id)sender
{
    self.monthDate = AddMonthsToMonth(12, self.monthDate);
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
    NSArray *months = [_formatter shortMonthSymbols];
    NSArray *dows = [_formatter veryShortWeekdaySymbols];
    NSString *month = [NSString stringWithFormat:@"%@ %d", months[self.monthDate.month], self.monthDate.year];
    [_monthLabel setStringValue:month];
    for (int i = 0; i < 7; i++) {
        NSString *dow = [NSString stringWithFormat:@"%@", dows[(i + self.weekStartDOW)%7]];
        [[_dowGrid.cells[i] textField] setStringValue:dow];
    }
    
    // Get the first of the month.
    MoDate firstOfMonth = MakeDate(self.monthDate.year, self.monthDate.month, 1);
    
    // Get the DOW for the first of the month.
    // en.wikipedia.org/wiki/Julian_day#Finding_day_of_week_given_Julian_day_number
    int monthStartDOW = (firstOfMonth.julian + 1)%7;
    
    // On which column [0..6] in the monthly calendar does this date fall?
    int monthStartColumn = DOW_COL(self.weekStartDOW, monthStartDOW);
    
    // Get the date for the first column of the monthly calendar.
    MoDate date = AddDaysToDate(-monthStartColumn, firstOfMonth);
    
    // On which column [0..6] in the monthly calendar does Monday fall?
    int mondayColumn = DOW_COL(self.weekStartDOW, 1); // 1=Monday
    
    // Fill in the calendar grid sequentially.
    for (int row = 0; row < 6; row++) {
        for (int col = 0; col < 7; col++) {
            MoCalCell *cell = _dateGrid.cells[row * 7 + col];
            cell.textField.stringValue = [NSString stringWithFormat:@"%d", date.day];
            cell.date = date;
            cell.isToday = CompareDates(date, self.todayDate) == 0;
            if (date.month == self.monthDate.month) {
                cell.textField.textColor = kDarkTextColor;
                if (date.day == 1) {
                    _monthStartCell = cell;
                }
                else if (date.day == DaysInMonth(date.year, date.month)) {
                    _monthEndCell = cell;
                }
            }
            else {
                cell.textField.textColor = kLightTextColor;
            }
            // ISO 8601 weeks are defined to start on Monday (and
            // really only make sense if self.weekStartDOW is Monday).
            // If the current column is Monday, use this date to
            // calculate the week number for this row.
            if (col == mondayColumn) {
                [_weekGrid.cells[row] textField].textColor = kLightTextColor;
                [_weekGrid.cells[row] textField].stringValue = [NSString stringWithFormat:@"%d", WeekOfYear(date.year, date.month, date.day)];
            }
            date = AddDaysToDate(1, date);
        }
    }
    [self setNeedsDisplay:YES];
}

- (void)reloadData
{

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
        _highlightPath = [self bezierPathWithStartCell:startCell endCell:endCell radius:2 inset:2.5 useRects:YES];
        _highlightColor = color;
        [self setNeedsDisplay:YES];
    }
}

- (void)unhighlightCells
{
    _highlightPath = nil;
    _highlightColor = nil;
    [self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Process input

- (void)keyDown:(NSEvent *)theEvent
{
    NSString *charsIgnoringModifiers = [theEvent charactersIgnoringModifiers];
    if (charsIgnoringModifiers.length != 1) return;
    
    NSUInteger flags = [theEvent modifierFlags];
    BOOL noFlags =  !(flags & (NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSShiftKeyMask));
    BOOL shiftFlag = (flags &  NSShiftKeyMask) && !(flags & (NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask));
    
    unichar keyChar = [charsIgnoringModifiers characterAtIndex:0];
    
    if (keyChar == ' ') {
        [_btnToday performClick:self];
    }
    else if ((keyChar == 'H' && shiftFlag) || (keyChar == NSLeftArrowFunctionKey && noFlags)) {
        [_btnPrev performClick:self];
    }
    else if ((keyChar == 'L' && shiftFlag) || (keyChar == NSRightArrowFunctionKey && noFlags)) {
        [_btnNext performClick:self];
    }
    else if ((keyChar == 'J' && shiftFlag) || (keyChar == NSDownArrowFunctionKey && noFlags)) {
        [self showNextYear:self];
    }
    else if ((keyChar == 'K' && shiftFlag) || (keyChar == NSUpArrowFunctionKey && noFlags)) {
        [self showPreviousYear:self];
    }
    else if ((keyChar == 'h' && noFlags) || (keyChar == NSLeftArrowFunctionKey && shiftFlag)) {
        [self moveSelectionByDays:-1];
    }
    else if ((keyChar == 'l' && noFlags) || (keyChar == NSRightArrowFunctionKey && shiftFlag)) {
        [self moveSelectionByDays:1];
    }
    else if ((keyChar == 'j' && noFlags) || (keyChar == NSDownArrowFunctionKey && shiftFlag)) {
        [self moveSelectionByDays:7];
    }
    else if ((keyChar == 'k' && noFlags) || (keyChar == NSUpArrowFunctionKey && shiftFlag)) {
        [self moveSelectionByDays:-7];
    }
    else if (keyChar == '1') {
        self.weekStartDOW = 1;
    }
    else if (keyChar == '0') {
        self.weekStartDOW = 0;
    }
    else {
        [super keyDown:theEvent];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint locationInWindow = [theEvent locationInWindow];
    NSPoint locationInDates  = [_dateGrid convertPoint:locationInWindow fromView:nil];
    MoCalCell *clickedCell   = [_dateGrid cellAtPoint:locationInDates];
    if (clickedCell && clickedCell != _selectedCell) {
        [self setMonthDate:self.monthDate selectedDate:clickedCell.date];
    }
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint locationInWindow = [theEvent locationInWindow];
    NSPoint locationInDates  = [_dateGrid convertPoint:locationInWindow fromView:nil];
    MoCalCell *hoveredCell   = [_dateGrid cellAtPoint:locationInDates];
    if (hoveredCell && hoveredCell != _hoveredCell) {
        _hoveredCell.isHovered = NO;
        _hoveredCell = hoveredCell;
        _hoveredCell.isHovered = YES;
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    _hoveredCell.isHovered = NO;
    _hoveredCell = nil;
    [self setNeedsDisplay:YES];
}

- (void)updateTrackingAreas
{
    // trackingRect encompasses the cells in _dateGrid (not including their margins)
    [self removeTrackingArea:_trackingArea];
    NSRect trackingRect = [self convertRect:[_dateGrid cellsRect] fromView:_dateGrid];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:trackingRect options:(NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
    [super updateTrackingAreas];
}

#pragma mark
#pragma mark Utilities

- (void)setMonthDate:(MoDate)monthDate selectedDate:(MoDate)selectedDate
{
    // This method is where the instance variables backing the
    // monthDate and selectedDate properties are set.
    
    BOOL didChangeMonth = NO;
    
    monthDate.day = 1;
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
    }
}

- (void)moveSelectionByDays:(int)days
{
    MoDate newSelectedDate = AddDaysToDate(days, self.selectedDate);
    MoDate firstCellDate = [(MoCalCell *)_dateGrid.cells.firstObject date];
    MoDate lastCellDate  = [(MoCalCell *)_dateGrid.cells.lastObject date];
    if (CompareDates(newSelectedDate, firstCellDate) < 0) {
        MoDate prevMonthDate = AddMonthsToMonth(-1, self.monthDate);
        [self setMonthDate:prevMonthDate selectedDate:newSelectedDate];
    }
    else if (CompareDates(newSelectedDate, lastCellDate) > 0) {
        MoDate nextMonthDate = AddMonthsToMonth(1, self.monthDate);
        [self setMonthDate:nextMonthDate selectedDate:newSelectedDate];
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

#pragma mark
#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect
{
    // If dirtyRect is contained in the top part of the calendar
    // which is just the plain background color, only draw that.
    // This will happen, for example, when the buttons are pressed.
    // Otherwise, redraw the whole view.
    
    [kBackgroundColor set];
    if (NSMinY(dirtyRect) > NSMaxY(_dateGrid.frame)+1) {
        NSRectFillUsingOperation(dirtyRect, NSCompositeSourceOver);
        return;
    }
    NSRectFillUsingOperation(self.bounds, NSCompositeSourceOver);
    
    [kOutlineColor set];
    NSRectFillUsingOperation(NSMakeRect(0, 0, NSWidth(self.bounds), NSMaxY(_dateGrid.frame)+1), NSCompositeSourceOver);
    
    [kWeeksBackgroundColor set];
    NSRectFillUsingOperation(_weekGrid.frame, NSCompositeSourceOver);
    
    [kDatesBackgroundColor set];
    NSRectFillUsingOperation(_dateGrid.frame, NSCompositeSourceOver);
    
    NSBezierPath *outlinePath = [self bezierPathWithStartCell:_monthStartCell endCell:_monthEndCell radius:4 inset:0 useRects:NO];
    
    [kOutlineColor set];
    [outlinePath setLineWidth:2];
    [outlinePath stroke];
    
    [[NSColor whiteColor] set];
    [NSGraphicsContext saveGraphicsState];
    [kShadow set];
    [outlinePath fill];
    [NSGraphicsContext restoreGraphicsState];
    
    if (_highlightPath) {
        NSColor *outlineColor = [_highlightColor shadowWithLevel:0.5];
        [[outlineColor colorWithAlphaComponent:0.3] setStroke];
        [[_highlightColor colorWithAlphaComponent:0.2] setFill];
        [_highlightPath stroke];
        [_highlightPath fill];
    }
}

- (NSBezierPath *)bezierPathWithStartCell:(MoCalCell *)startCell endCell:(MoCalCell *)endCell radius:(CGFloat)r inset:(CGFloat)inset useRects:(BOOL)useRects
{
    // Create a bezier path around the range of cells specified by
    // startCell and endCell. The path has rounded corners specified
    // by radius r. If useRects == YES, the path is composed only of
    // horizontal rounded rects. Otherwise, the path is a region.
    
    // First get the frame rects of the start and end cells in self view coordinates.
    
    NSRect startRect = [self convertRect:startCell.frame fromView:_dateGrid];
    NSRect endRect   = [self convertRect:endCell.frame fromView:_dateGrid];
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
        [p moveToPoint:NSMakePoint(x, y)];
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
            [p lineToPoint:NSMakePoint(x, y)];
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
            [p lineToPoint:NSMakePoint(x, y)];
        }
        [p closePath];
    }
    return p;
}

@end
