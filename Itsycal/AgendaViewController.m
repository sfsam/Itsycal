//
//  AgendaViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/18/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "Itsycal.h"
#import "AgendaViewController.h"
#import "EventCenter.h"
#import "MoButton.h"
#import "MoVFLHelper.h"
#import "Themer.h"
#import "Sizer.h"

static NSString *kColumnIdentifier    = @"Column";
static NSString *kDateCellIdentifier  = @"DateCell";
static NSString *kEventCellIdentifier = @"EventCell";

@interface ThemedScroller : NSScroller
@end

@interface AgendaRowView : NSTableRowView
@property (nonatomic) BOOL isHovered;
@end

@interface AgendaDateCell : NSView
@property (nonatomic) NSTextField *dayTextField;
@property (nonatomic) NSTextField *DOWTextField;
@property (nonatomic, weak) NSDate *date;
@property (nonatomic, readonly) CGFloat height;
@end

@interface AgendaEventCell : NSView
@property (nonatomic) NSGridView *grid;
@property (nonatomic) NSTextField *titleTextField;
@property (nonatomic) NSTextField *locationTextField;
@property (nonatomic) NSTextField *durationTextField;
@property (nonatomic, weak) EventInfo *eventInfo;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic) BOOL dim;
@end

@interface AgendaPopoverVC : NSViewController
@property (nonatomic) MoButton *btnDelete;
- (void)populateWithEventInfo:(EventInfo *)info;
- (NSSize)size;
@end

#pragma mark -
#pragma mark AgendaViewController

// =========================================================================
// AgendaViewController
// =========================================================================

@implementation AgendaViewController
{
    NSPopover *_popover;
}

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];

    // Calendars table view context menu
    NSMenu *contextMenu = [NSMenu new];
    contextMenu.delegate = self;

    // Calendars table view
    _tv = [MoTableView new];
    _tv.target = self;
    _tv.action = @selector(showPopover:);
    _tv.menu = contextMenu;
    _tv.headerView = nil;
    _tv.allowsColumnResizing = NO;
    _tv.intercellSpacing = NSMakeSize(0, 0);
    _tv.backgroundColor = NSColor.clearColor;
    _tv.floatsGroupRows = YES;
    _tv.refusesFirstResponder = YES;
    _tv.dataSource = self;
    _tv.delegate = self;
    [_tv addTableColumn:[[NSTableColumn alloc] initWithIdentifier:kColumnIdentifier]];
    
    // Calendars enclosing scrollview
    NSScrollView *tvContainer = [NSScrollView new];
    tvContainer.translatesAutoresizingMaskIntoConstraints = NO;
    tvContainer.drawsBackground = NO;
    tvContainer.hasVerticalScroller = YES;
    tvContainer.documentView = _tv;
    tvContainer.verticalScroller = [ThemedScroller new];
    
    [v addSubview:tvContainer];
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tv]|" options:0 metrics:nil views:@{@"tv": tvContainer}]];
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tv]|" options:0 metrics:nil views:@{@"tv": tvContainer}]];
    
    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self reloadData];
}

- (void)viewDidLayout
{
    // Calculate height of view based on _tv row heights.
    // We set the view's height using preferredContentSize.
    NSInteger rows = [_tv numberOfRows];
    CGFloat height = 0;
    for (NSInteger row = 0; row < rows; ++row) {
        height += [self tableView:_tv heightOfRow:row];
    }
    if ([self.identifier isEqualToString:@"AgendaVC"]) {
        // Limit height so everything fits on the screen.
        height = MIN(height, [self.delegate agendaMaxPossibleHeight]);
    }
    // If height is 0, we make it 0.001 which is effectively the
    // same dimension. When preferredContentSize is zero, it is
    // ignored, so we use a non-zero value that has the same
    // effect. Without this, the size won't shrink to zero when
    // transitioning from an agenda with events to one without.
    height = MAX(height, 0.001);
    self.preferredContentSize = NSMakeSize(NSWidth(_tv.frame), height);
}

- (void)updateViewConstraints
{
    // Tell _tv that row heights need to be recalculated.
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_tv numberOfRows])];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0];
    [_tv noteHeightOfRowsWithIndexesChanged:indexSet];
    [NSAnimationContext endGrouping];
    [super updateViewConstraints];
}

- (void)setShowLocation:(BOOL)showLocation
{
    if (_showLocation != showLocation) {
        _showLocation = showLocation;
        [self reloadData];
    }
}

- (void)reloadData
{
    [_tv reloadData];
    [_tv scrollRowToVisible:0];
    [[_tv enclosingScrollView] flashScrollers];
    [self.view setNeedsLayout:YES];
    [_popover close];
}

#pragma mark -
#pragma mark Context Menu

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    // Invoked just before menu is to be displayed.
    // Show a context menu ONLY for non-group rows.
    [menu removeAllItems];
    if (_tv.clickedRow < 0 || [self tableView:_tv isGroupRow:_tv.clickedRow]) return;
    [menu addItemWithTitle:NSLocalizedString(@"Copy", nil) action:@selector(copyEventToPasteboard:) keyEquivalent:@""];
    EventInfo *info = self.events[_tv.clickedRow];
    if (info.event.calendar.allowsContentModifications) {
        NSMenuItem *item =[menu addItemWithTitle:NSLocalizedString(@"Delete", nil) action:@selector(btnDeleteClicked:) keyEquivalent:@""];
        item.tag = _tv.clickedRow;
    }
}

#pragma mark -
#pragma mark Copy

- (void)copyEventToPasteboard:(id)sender
{
    if (_tv.clickedRow < 0 || [self tableView:_tv isGroupRow:_tv.clickedRow]) return;
    static NSDateIntervalFormatter *intervalFormatter = nil;
    if (intervalFormatter == nil) {
        intervalFormatter = [NSDateIntervalFormatter new];
        intervalFormatter.dateStyle = NSDateIntervalFormatterMediumStyle;
    }
    
    AgendaEventCell *cell = [_tv viewAtColumn:0 row:_tv.clickedRow makeIfNecessary:NO];
    
    if (cell == nil) return; // should not happen
    
    intervalFormatter.timeZone  = [NSTimeZone localTimeZone];
    // All-day events don't show time.
    intervalFormatter.timeStyle = cell.eventInfo.event.isAllDay
        ? NSDateIntervalFormatterNoStyle
        : NSDateIntervalFormatterShortStyle;
    // For single-day events, end date is same as start date.
    NSDate *endDate = cell.eventInfo.isSingleDay
        ? cell.eventInfo.event.startDate
        : cell.eventInfo.event.endDate;
    // Interval formatter just prints single date when from == to.
    NSString *duration = [intervalFormatter stringFromDate:cell.eventInfo.event.startDate toDate:endDate];
    // If the locale is English and we are in 12 hour time,
    // remove :00 from the time. Effect is 3:00 PM -> 3 PM.
    if ([[[NSLocale currentLocale] localeIdentifier] hasPrefix:@"en"]) {
        duration = [duration stringByReplacingOccurrencesOfString:@":00" withString:@""];
    }
    NSString *eventText = [NSString stringWithFormat:@"%@%@%@\n%@\n",
                           cell.titleTextField.stringValue,
                           cell.locationTextField.stringValue.length > 0 ? @"\n" : @"",
                           cell.locationTextField.stringValue,
                           duration];
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] writeObjects:@[eventText]];
}

#pragma mark -
#pragma mark Popover

- (void)showPopover:(id)sender
{
    if (_tv.clickedRow == -1 || [self tableView:_tv isGroupRow:_tv.clickedRow]) return;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self->_popover = [NSPopover new];
        self->_popover.contentViewController = [AgendaPopoverVC new];
        self->_popover.behavior = NSPopoverBehaviorTransient;
        self->_popover.animates = NO;
    });
    
    AgendaEventCell *cell = [_tv viewAtColumn:0 row:_tv.clickedRow makeIfNecessary:NO];
    
    if (!cell) return; // should never happen
    
    AgendaPopoverVC *popoverVC = (AgendaPopoverVC *)_popover.contentViewController;
    [popoverVC populateWithEventInfo:cell.eventInfo];
    
    if (cell.eventInfo.event.calendar.allowsContentModifications) {
        popoverVC.btnDelete.tag = _tv.clickedRow;
        popoverVC.btnDelete.target = self;
        popoverVC.btnDelete.action = @selector(btnDeleteClicked:);
        unichar backspaceKey = NSBackspaceCharacter;
        popoverVC.btnDelete.keyEquivalent = [NSString stringWithCharacters:&backspaceKey length:1];
    }
    
    [_popover setContentSize:popoverVC.size];
    [_popover setAppearance:NSApp.effectiveAppearance];
    [_popover showRelativeToRect:[_tv rectOfRow:_tv.clickedRow] ofView:_tv preferredEdge:NSRectEdgeMinX];
    
    // Prevent popoverVC's _note from eating key presses (like esc and delete).
    [popoverVC.view.window makeFirstResponder:popoverVC.btnDelete];
}

#pragma mark -
#pragma mark TableView delegate/datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.events == nil ? 0 : self.events.count;
}

- (NSTableRowView *)tableView:(MoTableView *)tableView rowViewForRow:(NSInteger)row
{
    AgendaRowView *rowView = [_tv makeViewWithIdentifier:@"RowView" owner:self];
    if (rowView == nil) {
        rowView = [AgendaRowView new];
        rowView.identifier = @"RowView";
    }
    rowView.isHovered = tableView.hoverRow == row;
    return rowView;
}

- (NSView *)tableView:(MoTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSView *v = nil;
    id obj = self.events[row];
    
    if ([obj isKindOfClass:[NSDate class]]) {
        AgendaDateCell *cell = [_tv makeViewWithIdentifier:kDateCellIdentifier owner:self];
        if (cell == nil) cell = [AgendaDateCell new];
        cell.date = obj;
        cell.dayTextField.stringValue = [self dayStringForDate:obj];
        cell.DOWTextField.stringValue = [self DOWStringForDate:obj];
        cell.dayTextField.textColor = Theme.agendaDayTextColor;
        cell.DOWTextField.textColor = Theme.agendaDOWTextColor;
        v = cell;
    }
    else {
        EventInfo *info = obj;
        AgendaEventCell *cell = [_tv makeViewWithIdentifier:kEventCellIdentifier owner:self];
        if (!cell) cell = [AgendaEventCell new];
        cell.eventInfo = info;
        [self populateEventCell:cell withInfo:info showLocation:self.showLocation];
        cell.dim = NO;
        // If event's endDate is today and is past, dim event.
        if (!info.isStartDate && !info.isAllDay &&
            [self.nsCal isDateInToday:info.event.endDate] &&
            [NSDate.date compare:info.event.endDate] == NSOrderedDescending) {
            cell.titleTextField.textColor = Theme.agendaEventDateTextColor;
            cell.dim = YES;
        }
        v = cell;
    }
    return v;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    // Keep a cell around for measuring event cell height.
    static AgendaDateCell *dateCell = nil;
    static AgendaEventCell *eventCell = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventCell = [AgendaEventCell new];
        dateCell = [AgendaDateCell new];
        dateCell.frame = NSMakeRect(0, 0, NSWidth(self->_tv.frame), 999); // only width is important here
        dateCell.dayTextField.integerValue = 21;
    });
    
    CGFloat height = dateCell.height;
    id obj = self.events[row];
    if ([obj isKindOfClass:[EventInfo class]]) {
        eventCell.frame = NSMakeRect(0, 0, NSWidth(_tv.frame), 999); // only width is important here
        [self populateEventCell:eventCell withInfo:obj showLocation:self.showLocation];
        height = eventCell.height;
    }
    return height;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    return [self.events[row] isKindOfClass:[NSDate class]];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return NO; // disable selection
}

- (void)tableView:(MoTableView *)tableView didHoverOverRow:(NSInteger)hoveredRow
{
    if (hoveredRow == -1 || [self tableView:_tv isGroupRow:hoveredRow]) {
        hoveredRow = -1;
    }
    for (NSInteger row = 0; row < [_tv numberOfRows]; row++) {
        if (![self tableView:_tv isGroupRow:row]) {
            AgendaRowView *rowView = [_tv rowViewAtRow:row makeIfNecessary:NO];
            rowView.isHovered = (row == hoveredRow);
        }
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaHoveredOverRow:)]) {
        [self.delegate agendaHoveredOverRow:hoveredRow];
    }
}

#pragma mark -
#pragma mark Delete event

- (void)btnDeleteClicked:(id)sender
{
    NSInteger row = [(MoButton *)sender tag];
    if (row < 0) return;
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaWantsToDeleteEvent:)]) {
        EventInfo *info = self.events[row];
        [self.delegate agendaWantsToDeleteEvent:info.event];
    }
}

#pragma mark -
#pragma mark Format Agenda Strings

- (NSString *)dayStringForDate:(NSDate *)date
{
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [NSDateFormatter new];
    }
    dateFormatter.timeZone = [NSTimeZone localTimeZone];
    [dateFormatter setLocalizedDateFormatFromTemplate:@"dMMM"];
    return [dateFormatter stringFromDate:date];
}

- (NSString *)DOWStringForDate:(NSDate *)date
{
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [NSDateFormatter new];
    }
    dateFormatter.timeZone = [NSTimeZone localTimeZone];
    if ([self.nsCal isDateInToday:date] || [self.nsCal isDateInTomorrow:date]) {
        dateFormatter.doesRelativeDateFormatting = YES;
        dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        dateFormatter.timeStyle = NSDateFormatterNoStyle;
    }
    else {
        dateFormatter.doesRelativeDateFormatting = NO;
        [dateFormatter setLocalizedDateFormatFromTemplate:@"EEEE"];
    }
    return [dateFormatter stringFromDate:date];
}

- (void)populateEventCell:(AgendaEventCell *)cell withInfo:(EventInfo *)info showLocation:(BOOL)showLocation
{
    static NSDateFormatter *timeFormatter = nil;
    static NSDateIntervalFormatter *intervalFormatter = nil;
    if (timeFormatter == nil) {
        timeFormatter = [NSDateFormatter new];
        timeFormatter.dateStyle = NSDateFormatterNoStyle;
        timeFormatter.timeStyle = NSDateFormatterShortStyle;
    }
    if (intervalFormatter == nil) {
        intervalFormatter = [NSDateIntervalFormatter new];
        intervalFormatter.dateStyle = NSDateIntervalFormatterNoStyle;
        intervalFormatter.timeStyle = NSDateIntervalFormatterShortStyle;
    }
    NSString *title = @"";
    NSString *location = @"";
    NSString *duration = @"";
    timeFormatter.timeZone  = [NSTimeZone localTimeZone];
    intervalFormatter.timeZone = nil; // Force tz update on macOS 10.13
    intervalFormatter.timeZone  = [NSTimeZone localTimeZone];
    
    if (info && info.event) {
        if (info.event.title) title = info.event.title;
        if (info.event.location) location = info.event.location;
    }
    
    // Hide location row IF !showLocation OR there's no location string.
    [cell.grid rowAtIndex:1].hidden = (!showLocation || location.length == 0);
    
    // Hide duration row for all day events.
    [cell.grid rowAtIndex:2].hidden = info.isAllDay;
    
    if (info.isAllDay == NO) {
        if (info.isStartDate == YES) {
            if (info.event.startDate != nil) {
                duration = [timeFormatter stringFromDate:info.event.startDate];
            }
        }
        else if (info.isEndDate == YES) {
            if (info.event.endDate != nil) {
                NSString *ends = NSLocalizedString(@"ends", @"Spanning event ends");
                duration = [NSString stringWithFormat:@"%@ %@", ends, [timeFormatter stringFromDate:info.event.endDate]];
            }
        }
        else {
            if (info.event.startDate != nil && info.event.endDate != nil) {
                duration = [intervalFormatter stringFromDate:info.event.startDate toDate:info.event.endDate];
            }
        }
        // If the locale is English and we are in 12 hour time,
        // remove :00 from the time. Effect is 3:00 PM -> 3 PM.
        if ([[[NSLocale currentLocale] localeIdentifier] hasPrefix:@"en"]) {
            if ([[timeFormatter dateFormat] rangeOfString:@"a"].location != NSNotFound) {
                duration = [duration stringByReplacingOccurrencesOfString:@":00" withString:@""];
            }
        }
    }
    cell.titleTextField.stringValue = title;
    cell.titleTextField.textColor = Theme.agendaEventTextColor;
    cell.locationTextField.stringValue = location;
    cell.locationTextField.textColor = Theme.agendaEventDateTextColor;
    cell.durationTextField.stringValue = duration;
    cell.durationTextField.textColor = Theme.agendaEventDateTextColor;
}

#pragma mark -
#pragma mark Dim past events

- (void)dimEventsIfNecessary
{
    // If the user has the window showing, reload the agenda cells.
    // This will redraw the events, dimming if necessary.
    if (self.view.window.isVisible) {
        [_tv reloadData];
    }
}

@end

#pragma mark -
#pragma mark ThemedScroller

// =========================================================================
// ThemedScroller
// =========================================================================

@implementation ThemedScroller

+ (BOOL)isCompatibleWithOverlayScrollers {
    return self == [ThemedScroller class];
}

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
    [Theme.mainBackgroundColor set];
    NSRectFill(slotRect);
}

@end

#pragma mark -
#pragma mark Agenda Row View

// =========================================================================
// AgendaRowView
// =========================================================================

@implementation AgendaRowView

- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    if (self.isHovered) {
        [Theme.agendaHoverColor set];
        NSRect rect = NSInsetRect(self.bounds, 2, 1);
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:5 yRadius:5] fill];
    }
}

- (void)setIsHovered:(BOOL)isHovered {
    if (_isHovered != isHovered) {
        _isHovered = isHovered;
        [self setNeedsDisplay:YES];
    }
}

@end

#pragma mark -
#pragma mark Agenda Date and Event cells

// =========================================================================
// AgendaDateCell
// =========================================================================

@implementation AgendaDateCell

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.identifier = kDateCellIdentifier;
        _dayTextField = [NSTextField labelWithString:@""];
        _dayTextField.translatesAutoresizingMaskIntoConstraints = NO;
        _dayTextField.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightSemibold];
        _dayTextField.textColor = Theme.agendaDayTextColor;
        [_dayTextField setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        _DOWTextField = [NSTextField labelWithString:@""];
        _DOWTextField.translatesAutoresizingMaskIntoConstraints = NO;
        _DOWTextField.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightSemibold];
        _DOWTextField.textColor = Theme.agendaDOWTextColor;

        [self addSubview:_dayTextField];
        [self addSubview:_DOWTextField];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_dayTextField, _DOWTextField)];
        [vfl :@"H:|-4-[_DOWTextField]-(>=4)-[_dayTextField]-4-|" :NSLayoutFormatAlignAllLastBaseline];
        [vfl :@"V:|-6-[_dayTextField]-1-|"];
        
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)sizeChanged:(id)sender
{
    _dayTextField.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightSemibold];
    _DOWTextField.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightSemibold];
}

- (CGFloat)height
{
    // The height of the textfield plus the height of the
    // top and bottom marigns.
    return [_dayTextField intrinsicContentSize].height + 7; // 6+1=top+bottom margin
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Must be opaque so rows can scroll under it.
    [Theme.mainBackgroundColor set];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
    NSRect r = NSMakeRect(4, self.bounds.size.height - 4, self.bounds.size.width - 8, 1);
    [Theme.agendaDividerColor set];
    NSRectFillUsingOperation(r, NSCompositingOperationSourceOver);
}

@end

// =========================================================================
// AgendaEventCell
// =========================================================================

@implementation AgendaEventCell {
    NSLayoutConstraint *_gridLeadingConstraint;
}

- (instancetype)init
{
    // Convenience function for making labels.
    NSTextField* (^label)(void) = ^NSTextField* () {
        NSTextField *lbl = [NSTextField labelWithString:@""];
        lbl.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize]];
        lbl.lineBreakMode = NSLineBreakByWordWrapping;
        lbl.cell.truncatesLastVisibleLine = YES;
        return lbl;
    };
    self = [super init];
    if (self) {
        self.identifier = kEventCellIdentifier;
        _titleTextField = label();
        _titleTextField.maximumNumberOfLines = 1;
        _locationTextField = label();
        _locationTextField.maximumNumberOfLines = 2;
        _durationTextField = label();
        _grid = [NSGridView gridViewWithViews:@[@[_titleTextField],
                                                @[_locationTextField],
                                                @[_durationTextField]]];
        _grid.translatesAutoresizingMaskIntoConstraints = NO;
        _grid.rowSpacing = 0;
        [self addSubview:_grid];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_grid)];
        [vfl :@"H:[_grid]-10-|"];
        [vfl :@"V:|-3-[_grid]"];
        
        CGFloat leadingConstant = [[Sizer shared] agendaEventLeadingMargin];
        _gridLeadingConstraint = [_grid.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:leadingConstant];
        _gridLeadingConstraint.active = YES;
        
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)sizeChanged:(id)sender
{
    _gridLeadingConstraint.constant = [[Sizer shared] agendaEventLeadingMargin];
    _titleTextField.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize]];
    _locationTextField.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize]];
    _durationTextField.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize]];
}

- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    // Setting preferredMaxLayoutWidth allows us to calculate height
    // after word-wrapping.
    // margins = leading + trailing margins
    CGFloat margins = _gridLeadingConstraint.constant + 10;
    _titleTextField.preferredMaxLayoutWidth = NSWidth(frame) - margins;
    _locationTextField.preferredMaxLayoutWidth = NSWidth(frame) - margins;
    _durationTextField.preferredMaxLayoutWidth = NSWidth(frame) - margins;
}

- (CGFloat)height
{
    // The height of the textfields (which may have word-wrapped)
    // plus the height of the top and bottom marigns.
    // top margin + bottom margin = 3 + 3 = 6
    return _grid.fittingSize.height + 6;
}

- (void)setDim:(BOOL)dim {
    if (_dim != dim) {
        _dim = dim;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    CGFloat alpha = self.dim ? 0.5 : 1;
    CGFloat x = 5;
    CGFloat yOffset = [[Sizer shared] fontSize] + 2;
    CGFloat dotWidthX = [[Sizer shared] agendaDotWidth];
    CGFloat dotWidthY = dotWidthX;
    CGFloat radius = dotWidthX / 2.0;
    NSColor *dotColor = self.eventInfo.event.calendar.color;
    if (self.eventInfo.isAllDay) {
        x += 1;
        yOffset += 2;
        dotWidthX -= 2;
        dotWidthY += 4;
        radius -= 1;
    }
    [[dotColor colorWithAlphaComponent:alpha] set];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, NSHeight(self.bounds) - yOffset, dotWidthX, dotWidthY) xRadius:radius yRadius:radius] fill];
}

@end

#pragma mark -
#pragma mark AgendaPopoverVC

// =========================================================================
// AgendaPopoverVC
// =========================================================================

#define POPOVER_TEXT_WIDTH 180

@implementation AgendaPopoverVC
{
    NSGridView  *_textGrid;
    NSGridView  *_grid;
    NSTextField *_title;
    NSTextField *_duration;
    NSTextField *_recurrence;
    NSTextView *_location;
    NSTextView *_note;
    NSDataDetector *_linkDetector;
    NSLayoutConstraint *_locHeight;
    NSLayoutConstraint *_noteHeight;
}

- (instancetype)init
{
    // Convenience function for making labels.
    NSTextField* (^label)(CGFloat) = ^NSTextField* (CGFloat weight) {
        NSTextField *lbl = [NSTextField wrappingLabelWithString:@""];
        lbl.preferredMaxLayoutWidth = POPOVER_TEXT_WIDTH;
        lbl.drawsBackground = NO;
        lbl.textColor = Theme.currentMonthTextColor;
        [lbl setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        return lbl;
    };
    self = [super init];
    if (self) {
        _title = label(NSFontWeightMedium);
        _duration = label(NSFontWeightRegular);
        _recurrence = label(NSFontWeightRegular);
        
        NSScrollView *locScrollView = [NSScrollView new];
        locScrollView.frame = NSMakeRect(0, 0, POPOVER_TEXT_WIDTH, 100);
        locScrollView.autoresizingMask = NSViewHeightSizable;
        locScrollView.drawsBackground = NO;
        
        _location = [NSTextView new];
        _location.frame = locScrollView.bounds;
        _location.autoresizingMask = NSViewHeightSizable;
        _location.editable = NO;
        _location.selectable = YES;
        _location.drawsBackground = NO;
        _location.textContainer.lineFragmentPadding = 0;
        _location.textContainer.size = NSMakeSize(POPOVER_TEXT_WIDTH, FLT_MAX);
        _location.textContainer.widthTracksTextView = YES;
        
        locScrollView.documentView = _location;
        
        NSScrollView *scrollView = [NSScrollView new];
        scrollView.frame = NSMakeRect(0, 0, POPOVER_TEXT_WIDTH, 100);
        scrollView.autoresizingMask = NSViewHeightSizable;
        scrollView.drawsBackground = NO;
        
        _note = [NSTextView new];
        _note.frame = scrollView.bounds;
        _note.autoresizingMask = NSViewHeightSizable;
        _note.editable = NO;
        _note.selectable = YES;
        _note.drawsBackground = NO;
        _note.textContainer.lineFragmentPadding = 0;
        _note.textContainer.size = NSMakeSize(POPOVER_TEXT_WIDTH, FLT_MAX);
        _note.textContainer.widthTracksTextView = YES;
        
        scrollView.documentView = _note;
        
        _btnDelete = [MoButton new];
        _btnDelete.image = [NSImage imageNamed:@"btnDel"];
        _btnDelete.image.template = YES;
        _btnDelete.focusRingType = NSFocusRingTypeNone;
        _textGrid = [NSGridView gridViewWithViews:@[@[_title],
                                                    @[locScrollView],
                                                    @[_duration],
                                                    @[_recurrence],
                                                    @[scrollView]]];
        _textGrid.rowSpacing = 8;
        [_textGrid rowAtIndex:4].topPadding = 4;
        [_textGrid columnAtIndex:0].width = _title.preferredMaxLayoutWidth;
        _grid = [NSGridView gridViewWithViews:@[@[_textGrid, _btnDelete]]];
        _grid.translatesAutoresizingMaskIntoConstraints = NO;
        _grid.rowSpacing = 0;
        _grid.columnSpacing = 5;
        _grid.yPlacement = NSGridCellPlacementCenter;
        _linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
        
        [locScrollView.widthAnchor constraintEqualToConstant:POPOVER_TEXT_WIDTH].active = YES;
        _locHeight = [locScrollView.heightAnchor constraintEqualToConstant:100];
        _locHeight.active = YES;

        [scrollView.widthAnchor constraintEqualToConstant:POPOVER_TEXT_WIDTH].active = YES;
        _noteHeight = [scrollView.heightAnchor constraintEqualToConstant:100];
        _noteHeight.active = YES;
    }
    return self;
}

- (void)loadView
{
    // Important to set width of view here. Otherwise popover
    // won't size propertly on first display.
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, POPOVER_TEXT_WIDTH, 1)];
    [view addSubview:_grid];
    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:view metrics:nil views:NSDictionaryOfVariableBindings(_grid)];
    [vfl :@"H:|-10-[_grid]-10-|"];
    [vfl :@"V:|-8-[_grid]-8-|"];
    self.view = view;
}

- (void)populateWithEventInfo:(EventInfo *)info
{
    static NSDateIntervalFormatter *intervalFormatter = nil;
    if (intervalFormatter == nil) {
        intervalFormatter = [NSDateIntervalFormatter new];
        intervalFormatter.dateStyle = NSDateIntervalFormatterMediumStyle;
    }
    NSString *title = @"";
    NSString *duration = @"";
    NSString *recurrence = @"";
    intervalFormatter.timeZone  = [NSTimeZone localTimeZone];
    
    if (info && info.event) {
        if (info.event.title) title = info.event.title;
    }
    
    // Hide location row IF there's no location string.
    [_textGrid rowAtIndex:1].hidden = !info.event.location;
    
    // Hide recurrence row IF there's no recurrence rule.
    [_textGrid rowAtIndex:3].hidden = !info.event.hasRecurrenceRules;
    
    // Hide note row IF there's no note.
    [_textGrid rowAtIndex:4].hidden = !info.event.hasNotes;
    
    // Hide delete button if event doesn't allow modification.
    [_grid columnAtIndex:1].hidden = !info.event.calendar.allowsContentModifications;
    
    // All-day events don't show time.
    intervalFormatter.timeStyle = info.event.isAllDay
        ? NSDateIntervalFormatterNoStyle
        : NSDateIntervalFormatterShortStyle;
    // For single-day events, end date is same as start date.
    NSDate *endDate = info.isSingleDay
        ? info.event.startDate
        : info.event.endDate;
    // Interval formatter just prints single date when from == to.
    duration = [intervalFormatter stringFromDate:info.event.startDate toDate:endDate];
    // If the locale is English and we are in 12 hour time,
    // remove :00 from the time. Effect is 3:00 PM -> 3 PM.
    if ([[[NSLocale currentLocale] localeIdentifier] hasPrefix:@"en"]) {
        duration = [duration stringByReplacingOccurrencesOfString:@":00" withString:@""];
    }
    // If the event is not All-day and the start and end dates are
    // different, put them on different lines.
    // The – is U+2013 (en-dash) and the space is U+2009 (thin space)
    if (!info.event.isAllDay) {
        NSDateComponents *start = [intervalFormatter.calendar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:info.event.startDate];
        NSDateComponents *end = [intervalFormatter.calendar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:info.event.endDate];
        if (start.day != end.day || start.month != end.month) {
            duration = [duration stringByReplacingOccurrencesOfString:@"– " withString:@"–\n"];
        }
    }
    // Recurrence.
    if (info.event.hasRecurrenceRules) {
        recurrence = [NSString stringWithFormat:@"%@ ", NSLocalizedString(@"Repeat:", nil)];
        EKRecurrenceRule *rule = info.event.recurrenceRules.firstObject;
        NSString *frequency = @"✓";
        switch (rule.frequency) {
            case EKRecurrenceFrequencyDaily:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Day", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Days", nil), rule.interval];
                break;
            case EKRecurrenceFrequencyWeekly:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Week", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Weeks", nil), rule.interval];
                break;
            case EKRecurrenceFrequencyMonthly:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Month", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Months", nil), rule.interval];
                break;
            case EKRecurrenceFrequencyYearly:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Year", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Years", nil), rule.interval];
                break;
            default:
                break;
        }
        recurrence = [recurrence stringByAppendingString:frequency];
        if (rule.recurrenceEnd) {
            if (rule.recurrenceEnd.endDate) {
                intervalFormatter.timeStyle = NSDateIntervalFormatterNoStyle;
                NSString *endRecurrence = [NSString stringWithFormat:@"\n%@ %@", NSLocalizedString(@"End Repeat:", nil), [intervalFormatter stringFromDate:rule.recurrenceEnd.endDate toDate:rule.recurrenceEnd.endDate]];
                recurrence = [recurrence stringByAppendingString:endRecurrence];
            }
            if (rule.recurrenceEnd.occurrenceCount) {
                NSString *endRecurrence = [NSString stringWithFormat:@"\n%@ ×%zd", NSLocalizedString(@"End Repeat:", nil), rule.recurrenceEnd.occurrenceCount];
                recurrence = [recurrence stringByAppendingString:endRecurrence];
            }
        }
    }
    
    // Location
    if (info.event.location) {
        NSString *trimmedLoc = [info.event.location stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmedLoc isEqualToString:@""]) {
            [_textGrid rowAtIndex:1].hidden = YES;
        }
        else {
            [self populateTextView:_location withString:trimmedLoc heightConstraint:_locHeight];
        }
    }

    // Notes
    if (info.event.hasNotes) {
        NSString *trimmedNotes = [info.event.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmedNotes isEqualToString:@""]) {
            [_textGrid rowAtIndex:4].hidden = YES;
        }
        else {
            [self populateTextView:_note withString:trimmedNotes heightConstraint:_noteHeight];
        }
    }
    _title.stringValue = title;
    _duration.stringValue = duration;
    _recurrence.stringValue = recurrence;
    
    _title.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightMedium];
    _duration.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightRegular];
    _recurrence.font = [NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightRegular];

    _title.textColor = Theme.agendaEventTextColor;
    _duration.textColor = Theme.agendaEventTextColor;
    _recurrence.textColor = Theme.agendaEventTextColor;
}

- (NSSize)size
{
    // The size of the grid plus the size of the margins.
    // 20 = 10 + 10 = left + right margins
    // 16 = 8 + 8 = top + bottom margins
    NSSize gridSize = _grid.fittingSize;
    return NSMakeSize(gridSize.width + 20, gridSize.height + 16);
}

- (void)populateTextView:(NSTextView *)textView withString:(NSString *)string heightConstraint:(NSLayoutConstraint *)constraint
{
    string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
    NSData *htmlData = [string dataUsingEncoding:NSUnicodeStringEncoding];
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithHTML:htmlData documentAttributes:nil];
    
    [attrString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:[[Sizer shared] fontSize]] range:NSMakeRange(0, attrString.length)];
    [attrString addAttribute:NSForegroundColorAttributeName value:Theme.agendaEventTextColor range:NSMakeRange(0, attrString.length)];
    [_linkDetector enumerateMatchesInString:attrString.string options:kNilOptions range:NSMakeRange(0, attrString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [attrString addAttribute:NSLinkAttributeName value:result.URL.absoluteString range:result.range];
    }];
    textView.textStorage.attributedString = attrString;
    // Force layout and then calculate text height.
    // stackoverflow.com/a/44969138/111418
    (void) [textView.layoutManager glyphRangeForTextContainer:textView.textContainer];
    NSRect textRect = [textView.layoutManager usedRectForTextContainer:textView.textContainer];
    
    // Set constraint to textView text height, but no more than 200.
    constraint.constant = MIN(textRect.size.height, 200);
    
    [textView scrollToBeginningOfDocument:nil];
}

@end
