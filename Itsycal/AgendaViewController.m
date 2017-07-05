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

static NSString *kColumnIdentifier    = @"Column";
static NSString *kDateCellIdentifier  = @"DateCell";
static NSString *kEventCellIdentifier = @"EventCell";

@interface AgendaRowView : NSTableRowView
@end

@interface AgendaDateCell : NSView
@property (nonatomic) NSTextField *dayTextField;
@property (nonatomic) NSTextField *DOWTextField;
@property (nonatomic, readonly) CGFloat height;
@end

@interface AgendaEventCell : NSView
@property (nonatomic) NSTextField *textField;
@property (nonatomic, weak) EventInfo *eventInfo;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic) MoButton *btnDelete;
@end

#pragma mark -
#pragma mark AgendaViewController

// =========================================================================
// AgendaViewController
// =========================================================================

@implementation AgendaViewController

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;

    // Calendars table view
    _tv = [MoTableView new];
    _tv.headerView = nil;
    _tv.allowsColumnResizing = NO;
    _tv.intercellSpacing = NSMakeSize(0, 0);
    _tv.backgroundColor = [[Themer shared] mainBackgroundColor];
    _tv.hoverColor = [[Themer shared] agendaHoverColor];
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
    
    [v addSubview:tvContainer];
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tv]|" options:0 metrics:nil views:@{@"tv": tvContainer}]];
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tv]|" options:0 metrics:nil views:@{@"tv": tvContainer}]];
    
    self.view = v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    REGISTER_FOR_THEME_CHANGE;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [_tv reloadData];
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
    // Limit view height to a max of 500.
    height = MIN(height, 500);
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

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    _backgroundColor = backgroundColor;
    _tv.backgroundColor = backgroundColor;
}

- (void)reloadData
{
    [_tv reloadData];
    [_tv scrollRowToVisible:0];
    [[_tv enclosingScrollView] flashScrollers];
    [self.view setNeedsLayout:YES];
}

- (void)themeChanged:(id)sender
{
    _tv.hoverColor = [[Themer shared] agendaHoverColor];    
    self.backgroundColor = [[Themer shared] mainBackgroundColor];
    for (NSInteger row = 0; row < _tv.numberOfRows; row++) {
        NSView *cell = [_tv viewAtColumn:0 row:row makeIfNecessary:YES];
        [cell setNeedsDisplay:YES];
    }    
}

#pragma mark -
#pragma mark TableView delegate/datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.events == nil ? 0 : self.events.count;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    AgendaRowView *rowView = [_tv makeViewWithIdentifier:@"RowView" owner:self];
    if (rowView == nil) {
        rowView = [AgendaRowView new];
        rowView.identifier = @"RowView";
    }
    return rowView;
}

- (NSView *)tableView:(MoTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSView *v = nil;
    id obj = self.events[row];
    
    if ([obj isKindOfClass:[NSDate class]]) {
        AgendaDateCell *cell = [_tv makeViewWithIdentifier:kDateCellIdentifier owner:self];
        if (cell == nil) cell = [AgendaDateCell new];
        cell.dayTextField.stringValue = [self dayStringForDate:obj];
        cell.DOWTextField.stringValue = [self DOWStringForDate:obj];
        v = cell;
    }
    else {
        EventInfo *info = obj;
        AgendaEventCell *cell = [_tv makeViewWithIdentifier:kEventCellIdentifier owner:self];
        if (!cell) cell = [AgendaEventCell new];
        cell.textField.attributedStringValue = [self eventStringForInfo:info];
        cell.toolTip = info.event.location;
        cell.eventInfo = info;
        BOOL allowsModification = cell.eventInfo.event.calendar.allowsContentModifications;
        cell.btnDelete.hidden = (tableView.hoverRow == row && allowsModification) ? NO : YES;
        cell.btnDelete.tag = row;
        cell.btnDelete.target = self;
        cell.btnDelete.action = @selector(btnDeleteClicked:);
        v = cell;
    }
    return v;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    // Keep a cell around for measuring event cell height.
    static AgendaEventCell *eventCell = nil;
    static CGFloat dateCellHeight = 0;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventCell = [AgendaEventCell new];
        AgendaDateCell *dateCell = [AgendaDateCell new];
        dateCell.frame = NSMakeRect(0, 0, NSWidth(_tv.frame), 999); // only width is important here
        dateCell.dayTextField.stringValue = @"21";
        dateCellHeight = dateCell.height;
    });
    
    CGFloat height = dateCellHeight;
    id obj = self.events[row];
    if ([obj isKindOfClass:[EventInfo class]]) {
        eventCell.frame = NSMakeRect(0, 0, NSWidth(_tv.frame), 999); // only width is important here
        eventCell.textField.attributedStringValue = [self eventStringForInfo:obj];
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
    // Hide all delete buttons except for hoveredRow.
    for (NSInteger row = 0; row < [_tv numberOfRows]; row++) {
        if (![self tableView:_tv isGroupRow:row]) {
            AgendaEventCell *cell = [_tv viewAtColumn:0 row:row makeIfNecessary:NO];
            BOOL allowsModification = cell.eventInfo.event.calendar.allowsContentModifications;
            cell.btnDelete.hidden = (row == hoveredRow && allowsModification) ? NO : YES;
        }
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaHoveredOverRow:)]) {
        [self.delegate agendaHoveredOverRow:hoveredRow];
    }
}

#pragma mark -
#pragma mark Delete event

- (void)btnDeleteClicked:(MoButton *)btn
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaWantsToDeleteEvent:)]) {
        EventInfo *info = self.events[btn.tag];
        [self.delegate agendaWantsToDeleteEvent:info.event];
    }
}

#pragma mark -
#pragma mark Date string

- (NSString *)dayStringForDate:(NSDate *)date
{
    NSInteger day = [self.nsCal component:NSCalendarUnitDay fromDate:date];
    return [NSString stringWithFormat:@"%zd ", day];
}

- (NSString *)DOWStringForDate:(NSDate *)date
{
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [NSDateFormatter new];
    }
    dateFormatter.timeZone = [NSTimeZone localTimeZone];
    dateFormatter.dateFormat = @"EEEE";
    NSString *dow = [dateFormatter stringFromDate:date];
    // If the date is today or tomorrow, use "Today" or "Tomorrow" as the dow.
    if (self.nsCal && ([self.nsCal isDateInToday:date] || [self.nsCal isDateInTomorrow:date])) {
        dateFormatter.doesRelativeDateFormatting = YES;
        dateFormatter.dateStyle = NSDateFormatterShortStyle;
        dow = [dateFormatter stringFromDate:date];
    }
    return dow;
}

- (NSAttributedString *)eventStringForInfo:(EventInfo *)info
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
    NSString *title = info == nil ? @"" : info.event.title;
    NSString *duration = @"";
    timeFormatter.timeZone  = [NSTimeZone localTimeZone];
    intervalFormatter.timeZone  = [NSTimeZone localTimeZone];
    if (info.isAllDay == NO) {
        if (info.isStartDate == YES) {
            duration = [NSString stringWithFormat:@"\n%@", [timeFormatter stringFromDate:info.event.startDate]];
        }
        else if (info.isEndDate == YES) {
            NSString *ends = NSLocalizedString(@"ends", @"Spanning event ends");
            duration = [NSString stringWithFormat:@"\n%@ %@", ends, [timeFormatter stringFromDate:info.event.endDate]];
        }
        else {
            duration = [NSString stringWithFormat:@"\n%@", [intervalFormatter stringFromDate:info.event.startDate toDate:info.event.endDate]];
        }
        // If the locale is English and we are in 12 hour time,
        // remove :00 from the time. Effect is 3:00 PM -> 3 PM.
        if ([[[NSLocale currentLocale] localeIdentifier] hasPrefix:@"en"]) {
            if ([[timeFormatter dateFormat] rangeOfString:@"a"].location != NSNotFound) {
                duration = [duration stringByReplacingOccurrencesOfString:@":00" withString:@""];
            }
        }
    }
    NSString *string = [NSString stringWithFormat:@"%@%@", title, duration];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:string];
    [s addAttributes:@{NSForegroundColorAttributeName: [[Themer shared] agendaEventTextColor]} range:NSMakeRange(0, title.length)];
    return s;
}

@end

#pragma mark -
#pragma mark Agenda Row View

// =========================================================================
// AgendaRowView
// =========================================================================

@implementation AgendaRowView

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.isGroupRowStyle) {
        [[self backgroundColor] set]; // tableView's background color
        NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
        NSRect r = NSMakeRect(6, 8, self.bounds.size.width - 12, 1);
        [[[Themer shared] agendaDividerColor] set];
        NSRectFillUsingOperation(r, NSCompositingOperationSourceOver);
    }
    else {
        [super drawRect:dirtyRect];
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
        _dayTextField.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
        _dayTextField.textColor = [[Themer shared] agendaDayTextColor];
        _dayTextField.drawsBackground = YES;
        _dayTextField.backgroundColor = [[Themer shared] mainBackgroundColor];
        [_dayTextField setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        _DOWTextField = [NSTextField labelWithString:@""];
        _DOWTextField.translatesAutoresizingMaskIntoConstraints = NO;
        _DOWTextField.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
        _DOWTextField.textColor = [[Themer shared] agendaDOWTextColor];

        [self addSubview:_dayTextField];
        [self addSubview:_DOWTextField];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_dayTextField, _DOWTextField)];
        [vfl :@"H:|-4-[_dayTextField]"];
        [vfl :@"H:[_dayTextField][_DOWTextField]" :NSLayoutFormatAlignAllLastBaseline];
        [vfl :@"V:|-5-[_dayTextField]-3-|"];
    }
    return self;
}

- (CGFloat)height
{
    // The height of the textfield plus the height of the
    // top and bottom marigns.
    return [_dayTextField intrinsicContentSize].height + 8; // 5 + 3 = top + bottom margin
}

- (void)setNeedsDisplay:(BOOL)needsDisplay
{
    _dayTextField.backgroundColor = [[Themer shared] mainBackgroundColor];
    _dayTextField.textColor = [[Themer shared] agendaDayTextColor];
    _DOWTextField.textColor = [[Themer shared] agendaDOWTextColor];
    [super setNeedsDisplay:needsDisplay];
}

@end

// =========================================================================
// AgendaEventCell
// =========================================================================

@implementation AgendaEventCell

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.identifier = kEventCellIdentifier;
        _textField = [NSTextField new];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [NSFont systemFontOfSize:11];
        _textField.textColor = [[Themer shared] agendaEventDateTextColor];
        _textField.lineBreakMode = NSLineBreakByWordWrapping;
        _textField.editable = NO;
        _textField.bezeled = NO;
        _textField.drawsBackground = NO;
        _textField.stringValue = @"";
        _btnDelete = [MoButton new];
        _btnDelete.image = [NSImage imageNamed:@"btnDel"];
        [self addSubview:_textField];
        [self addSubview:_btnDelete];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-16-[_textField]-8-|" options:0 metrics:nil views:@{@"_textField": _textField}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-3-[_textField]" options:0 metrics:nil views:@{@"_textField": _textField}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_btnDelete]-6-|" options:0 metrics:nil views:@{@"_btnDelete": _btnDelete}]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_btnDelete attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    }
    return self;
}

- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    // Setting preferredMaxLayoutWidth on _textfield allows us
    // to calculate its height after word-wrapping.
    _textField.preferredMaxLayoutWidth = NSWidth(frame) - 24; // 24=16+8=left+right margin
}

- (CGFloat)height
{
    // The height of the textfield (which may have word-wrapped)
    // plus the height of the top and bottom marigns.
    return [_textField intrinsicContentSize].height + 6; // 6=3+3=top+bottom margin
}

- (void)setNeedsDisplay:(BOOL)needsDisplay
{
    _textField.textColor = [[Themer shared] agendaEventDateTextColor];
    [super setNeedsDisplay:needsDisplay];
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Draw a colored circle.
    NSRect circleRect = NSMakeRect(6, NSMaxY(self.frame)-13, 6, 6);
    [self.eventInfo.event.calendar.color set];
    [[NSBezierPath bezierPathWithOvalInRect:circleRect] fill];
}

@end
