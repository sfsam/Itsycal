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
#import "MoButton.h"

static NSShadow *kShadow=nil;
static NSColor *kBackgroundColor=nil, *kWeeksBackgroundColor=nil, *kDatesBackgroundColor=nil, *kBorderColor=nil, *kOutlineColor=nil, *kLightTextColor=nil, *kDarkTextColor=nil, *kWeekendTextColor=nil;

@implementation MoCalendar
{
    NSDateFormatter *_formatter;
    NSTextField *_monthLabel;
    MoCalGrid *_dateGrid;
    MoCalGrid *_weekGrid;
    MoCalGrid *_dowGrid;
    MoCalToolTipWC *_tooltipWC;
    MoButton *_btnPrev, *_btnNext, *_btnToday;
    NSLayoutConstraint *_weeksConstraint;
    NSTrackingArea *_trackingArea;
    __weak MoCalCell *_hoveredCell;
    __weak MoCalCell *_selectedCell;
    __weak MoCalCell *_monthStartCell;
    __weak MoCalCell *_monthEndCell;
    NSBezierPath *_highlightPath;
    NSColor *_highlightColor;
    NSColor *_weekendTextColor;
}

+ (void)initialize
{
    kShadow = [NSShadow new];
    kShadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.3];
    kShadow.shadowBlurRadius = 2;
    kShadow.shadowOffset = NSMakeSize(0, -1);
    kBorderColor = [NSColor colorWithRed:0.86 green:0.86 blue:0.88 alpha:1];
    kOutlineColor = [NSColor colorWithRed:0.7 green:0.7 blue:0.73 alpha:1];
    kLightTextColor = [NSColor colorWithWhite:0.15 alpha:0.6];
    kDarkTextColor  = [NSColor colorWithWhite:0.15 alpha:1];
    kWeekendTextColor = [NSColor colorWithRed:0.75 green:0.2 blue:0.1 alpha:1];
    kBackgroundColor = [NSColor whiteColor];
    kWeeksBackgroundColor = [NSColor colorWithRed:0.86 green:0.86 blue:0.88 alpha:1];
    kDatesBackgroundColor = [NSColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1];
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
    _tooltipWC = [MoCalToolTipWC new];
    
    _monthLabel = [NSTextField new];
    _monthLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _monthLabel.font = [NSFont fontWithName:@"VarelaRoundNeo-Bold" size:13];
    _monthLabel.textColor = kDarkTextColor;
    _monthLabel.bezeled = NO;
    _monthLabel.editable = NO;
    _monthLabel.drawsBackground = NO;
    
    // Make long labels compress and show ellipsis instead of forcing the window wider.
    // Prevent short label from pulling buttons leftward toward it.
    [_monthLabel setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_monthLabel setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [_monthLabel setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    // Convenience function to make buttons.
    MoButton* (^btn)(NSString*, SEL) = ^MoButton* (NSString *imageName, SEL action) {
        MoButton *btn = [MoButton new];
        [btn setButtonType:NSMomentaryChangeButton];
        [btn setBordered:NO];
        [btn setImage:[NSImage imageNamed:imageName]];
        [btn setAlternateImage:[NSImage imageNamed:[imageName stringByAppendingString:@"Alt"]]];
        [btn setTarget:self];
        [btn setAction:action];
        [btn setImagePosition:NSImageOnly];
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
    
    for (MoCalCell *cell in _dowGrid.cells) {
        cell.textField.font = [NSFont fontWithName:@"VarelaRoundNeo-Bold" size:11];
        cell.textField.textColor = kDarkTextColor;
    }
    
    [self addSubview:_monthLabel];
    [self addSubview:_dateGrid];
    [self addSubview:_weekGrid];
    [self addSubview:_dowGrid];
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*, NSLayoutFormatOptions) = ^(NSString *format, NSLayoutFormatOptions opts) {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:opts metrics:nil views:NSDictionaryOfVariableBindings(_monthLabel, _btnPrev, _btnToday, _btnNext, _dowGrid, _weekGrid, _dateGrid)]];
    };
    vcon(@"H:|-8-[_monthLabel]-4-[_btnPrev]-2-[_btnToday]-2-[_btnNext]-6-|", NSLayoutFormatAlignAllCenterY);
    vcon(@"H:[_dowGrid]|", 0);
    vcon(@"H:[_weekGrid][_dateGrid]|", 0);
    vcon(@"V:|-(-3)-[_monthLabel]-1-[_dowGrid][_dateGrid]-1-|", 0);
    vcon(@"V:[_weekGrid]-1-|", 0);
    
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

- (void)setHighlightWeekend:(BOOL)highlightWeekend
{
    _highlightWeekend = highlightWeekend;
    _weekendTextColor = highlightWeekend ? kWeekendTextColor : kDarkTextColor;
    [self updateCalendar];
}

- (void)setTooltipVC:(NSViewController<MoCalTooltipProvider> *)tooltipVC
{
    _tooltipVC = tooltipVC;
    _tooltipWC.vc = tooltipVC;

    NSView *contentView = _tooltipWC.window.contentView;
    
    // Remove all subviews of tooltip window's contentView.
    [contentView setSubviews:@[]];

    // Add the tooltopVC's view as a subview of the tooltip
    // window's contentView.
    if (tooltipVC != nil) {
        tooltipVC.view.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:tooltipVC.view];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-3-[v]-3-|" options:0 metrics:nil views:@{@"v":_tooltipVC.view}]];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-2-[v]-2-|" options:0 metrics:nil views:@{@"v":_tooltipVC.view}]];
    }
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
    // On which column [0..6] in the monthly calendar do these days fall?
    NSInteger sundayColumn   = DOW_COL(self.weekStartDOW, 0); // 0=Sunday
    NSInteger mondayColumn   = DOW_COL(self.weekStartDOW, 1); // 1=Monday
    NSInteger saturdayColumn = DOW_COL(self.weekStartDOW, 6); // 6=Saturday
    
    // Month/year and DOW labels
    NSArray *months = [_formatter shortMonthSymbols];
    NSArray *dows = [_formatter veryShortWeekdaySymbols];
    NSString *month = [NSString stringWithFormat:@"%@ %zd", months[self.monthDate.month], self.monthDate.year];
    [_monthLabel setStringValue:month];
    for (NSInteger col = 0; col < 7; col++) {
        NSString *dow = [NSString stringWithFormat:@"%@", dows[(col + self.weekStartDOW)%7]];
        // Make French dow strings lowercase because that is the convention
        // in France. -veryShortWeekdaySymbols should have done this for us.
        if ([[NSLocale currentLocale].localeIdentifier hasPrefix:@"fr"]) {
            dow = [dow lowercaseString];
        }
        [[_dowGrid.cells[col] textField] setStringValue:dow];
        [[_dowGrid.cells[col] textField] setTextColor:kDarkTextColor];
        if (col == sundayColumn || col == saturdayColumn) {
            [[_dowGrid.cells[col] textField] setTextColor:_weekendTextColor];
        }
    }
    
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
    for (NSInteger row = 0; row < 6; row++) {
        for (NSInteger col = 0; col < 7; col++) {
            MoCalCell *cell = _dateGrid.cells[row * 7 + col];
            cell.textField.stringValue = [NSString stringWithFormat:@"%zd", date.day];
            cell.date = date;
            cell.isToday = CompareDates(date, self.todayDate) == 0;
            if (date.month == self.monthDate.month) {
                cell.textField.textColor = kDarkTextColor;
                if (col == sundayColumn || col == saturdayColumn) {
                    cell.textField.textColor = _weekendTextColor;
                }
                if (date.day == 1) {
                    _monthStartCell = cell;
                }
                else if (date.day == DaysInMonth(date.year, date.month)) {
                    _monthEndCell = cell;
                }
            }
            else {
                cell.textField.textColor = kLightTextColor;
                if (col == sundayColumn || col == saturdayColumn) {
                    cell.textField.textColor = [_weekendTextColor colorWithAlphaComponent:0.6];
                }
            }
            // ISO 8601 weeks are defined to start on Monday (and
            // really only make sense if self.weekStartDOW is Monday).
            // If the current column is Monday, use this date to
            // calculate the week number for this row.
            if (col == mondayColumn) {
                [_weekGrid.cells[row] textField].textColor = kLightTextColor;
                [_weekGrid.cells[row] textField].stringValue = [NSString stringWithFormat:@"%zd", WeekOfYear(date.year, date.month, date.day)];
            }
            date = AddDaysToDate(1, date);
        }
    }
    [self setNeedsDisplay:YES];
    
    [self.delegate calendarUpdated:self];
}

- (void)reloadData
{
    for (MoCalCell *c in _dateGrid.cells) {
        c.hasDot = [self.delegate dateHasDot:c.date];
    }
    [_tooltipWC endTooltip];
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
    else {
        [super keyDown:theEvent];
    }
    [_tooltipWC endTooltip];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint locationInWindow = [theEvent locationInWindow];
    NSPoint locationInDates  = [_dateGrid convertPoint:locationInWindow fromView:nil];
    MoCalCell *clickedCell   = [_dateGrid cellAtPoint:locationInDates];
    if (clickedCell && clickedCell != _selectedCell) {
        [self setMonthDate:self.monthDate selectedDate:clickedCell.date];
    }
    [_tooltipWC hideTooltip];
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
        
        if (_hoveredCell.hasDot && _tooltipVC != nil) {
            NSRect rect = [self convertRect:_hoveredCell.frame fromView:_dateGrid];
            rect = NSOffsetRect(rect, self.frame.origin.x, self.frame.origin.y);
            rect = [self.window convertRectToScreen:rect];
            [_tooltipWC showTooltipForDate:_hoveredCell.date relativeToRect:rect screenFrame:[[NSScreen mainScreen] frame]];
        }
        else {
            [_tooltipWC hideTooltip];
        }

    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    _hoveredCell.isHovered = NO;
    _hoveredCell = nil;
    [_tooltipWC hideTooltip];
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
        [self.delegate calendarSelectionChanged:self];
    }
}

- (void)moveSelectionByDays:(NSInteger)days
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
    
    [kBorderColor set];
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
    
    if (self.highlightWeekend) {
        NSRect weekendRect = [self convertRect:[_dateGrid cellsRect] fromView:_dateGrid];
        weekendRect.size.width = kMoCalCellWidth;
        NSRect sundayRect   = NSOffsetRect(weekendRect, DOW_COL(self.weekStartDOW, 0) * kMoCalCellWidth, 0);
        NSRect saturdayRect = NSOffsetRect(weekendRect, DOW_COL(self.weekStartDOW, 6) * kMoCalCellWidth, 0);
        [[NSColor colorWithWhite:0.15 alpha:0.05] set];
        if (self.weekStartDOW == 0) {
            [[NSBezierPath bezierPathWithRoundedRect:sundayRect xRadius:4 yRadius:4] fill];
            [[NSBezierPath bezierPathWithRoundedRect:saturdayRect xRadius:4 yRadius:4] fill];
        }
        else {
            weekendRect = NSUnionRect(sundayRect, saturdayRect);
            [[NSBezierPath bezierPathWithRoundedRect:weekendRect xRadius:4 yRadius:4] fill];
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
        NSColor *outlineColor = [_highlightColor blendedColorWithFraction:0.6 ofColor:[NSColor blackColor]];
        [[outlineColor colorWithAlphaComponent:0.3] setStroke];
        [[_highlightColor colorWithAlphaComponent:0.2] setFill];
        [highlightPath stroke];
        [highlightPath fill];
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
