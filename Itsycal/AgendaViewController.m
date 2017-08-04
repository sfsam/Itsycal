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

@interface ThemedScroller : NSScroller
@end

@interface AgendaRowView : NSTableRowView
@end

@interface AgendaDateCell : NSView
@property (nonatomic) NSTextField *dayTextField;
@property (nonatomic) NSTextField *DOWTextField;
@property (nonatomic, weak) NSDate *date;
@property (nonatomic, readonly) CGFloat height;
@end

@interface AgendaEventCell : NSView
@property (nonatomic) NSTextField *textField;
@property (nonatomic, weak) EventInfo *eventInfo;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic) MoButton *btnDelete;
@property (nonatomic) NSView *colorCircle;
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
    if (OSVersionIsAtLeast(10, 13, 0)) {
        // 10.13+: so layer-backed btnDelete draws in correct position consistently
        _tv.wantsLayer = YES; 
    }
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
    tvContainer.verticalScroller = [ThemedScroller new];
    
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
    [self dimEventsIfNecessary];
    [self.view setNeedsLayout:YES];
}

- (void)themeChanged:(id)sender
{
    _tv.hoverColor = [[Themer shared] agendaHoverColor];
    [_tv.enclosingScrollView.verticalScroller setNeedsDisplay];
    self.backgroundColor = [[Themer shared] mainBackgroundColor];
    [self reloadData];
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
        cell.date = obj;
        cell.dayTextField.stringValue = [self dayStringForDate:obj];
        cell.DOWTextField.stringValue = [self DOWStringForDate:obj];
        cell.dayTextField.textColor = [[Themer shared] agendaDayTextColor];
        cell.DOWTextField.textColor = [[Themer shared] agendaDOWTextColor];
        v = cell;
    }
    else {
        EventInfo *info = obj;
        AgendaEventCell *cell = [_tv makeViewWithIdentifier:kEventCellIdentifier owner:self];
        if (!cell) cell = [AgendaEventCell new];
        cell.eventInfo = info;
        cell.textField.attributedStringValue = [self eventStringForInfo:info];
        cell.textField.textColor = [[Themer shared] agendaEventDateTextColor];
        cell.toolTip = self.showLocation ? nil : info.event.location;
        BOOL allowsModification = cell.eventInfo.event.calendar.allowsContentModifications;
        cell.btnDelete.hidden = (tableView.hoverRow == row && allowsModification) ? NO : YES;
        cell.btnDelete.tag = row;
        cell.btnDelete.target = self;
        cell.btnDelete.action = @selector(btnDeleteClicked:);
        cell.colorCircle.layer.backgroundColor = info.event.calendar.color.CGColor;
        cell.colorCircle.alphaValue = 1;
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
        dateCell.dayTextField.integerValue = 21;
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
    NSString *location = @"";
    NSString *duration = @"";
    timeFormatter.timeZone  = [NSTimeZone localTimeZone];
    intervalFormatter.timeZone  = [NSTimeZone localTimeZone];
    
    if (self.showLocation) {
        if (info.event.location) {
            location = [NSString stringWithFormat:@"\n%@", info.event.location];
        }
    }
    
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
    NSString *string = [NSString stringWithFormat:@"%@%@%@", title, location, duration];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:string];
    [s addAttributes:@{NSForegroundColorAttributeName: [[Themer shared] agendaEventTextColor]} range:NSMakeRange(0, title.length)];
    return s;
}

#pragma mark -
#pragma mark Dim past events

- (void)dimEventsIfNecessary
{
    // Iterate through the rows of the table and dim past
    // events if they are today.
    BOOL isToday = NO;
    NSDate *now = [NSDate new];
    for (NSInteger row = 0; row < _tv.numberOfRows; row++) {
        NSView *cell = [_tv viewAtColumn:0 row:row makeIfNecessary:YES];
        if ([cell isKindOfClass:[AgendaDateCell class]]) {
            isToday = [self.nsCal isDateInToday:((AgendaDateCell *)cell).date];
        }
        else if (isToday) {
            AgendaEventCell *eventCell = (AgendaEventCell *)cell;
            if ([now compare:eventCell.eventInfo.event.endDate] == NSOrderedDescending) {
                // This looks pointless, but I'm clearing the attributes so the
                // next line where I set textColor will color the whole string.
                eventCell.textField.stringValue = eventCell.textField.stringValue;
                eventCell.textField.textColor = [[Themer shared] agendaEventDateTextColor];
                eventCell.colorCircle.alphaValue = 0.5;
            }
        }
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
    [[[Themer shared] mainBackgroundColor] set];
    NSRectFill(slotRect);
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
        NSRect r = NSMakeRect(4, 3, self.bounds.size.width - 8, 1);
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
        _dayTextField.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
        _dayTextField.textColor = [[Themer shared] agendaDayTextColor];
        [_dayTextField setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        _DOWTextField = [NSTextField labelWithString:@""];
        _DOWTextField.translatesAutoresizingMaskIntoConstraints = NO;
        _DOWTextField.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
        _DOWTextField.textColor = [[Themer shared] agendaDOWTextColor];

        [self addSubview:_dayTextField];
        [self addSubview:_DOWTextField];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_dayTextField, _DOWTextField)];
        [vfl :@"H:|-4-[_DOWTextField]-(>=4)-[_dayTextField]-4-|" :NSLayoutFormatAlignAllLastBaseline];
        [vfl :@"V:|-6-[_dayTextField]-1-|"];
    }
    return self;
}

- (CGFloat)height
{
    // The height of the textfield plus the height of the
    // top and bottom marigns.
    return [_dayTextField intrinsicContentSize].height + 7; // 6+1=top+bottom margin
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
        _colorCircle = [NSView new];
        _colorCircle.translatesAutoresizingMaskIntoConstraints = NO;
        _colorCircle.wantsLayer = YES;
        _colorCircle.layer.cornerRadius = 3;
        [self addSubview:_textField];
        [self addSubview:_btnDelete];
        [self addSubview:_colorCircle];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_textField, _btnDelete, _colorCircle)];
        [vfl :@"H:|-16-[_textField]-20-|"]; // margins for colored dot, delete button
        [vfl :@"V:|-3-[_textField]"];
        [vfl :@"H:[_btnDelete]-4-|"];
        [vfl :@"H:|-6-[_colorCircle(6)]"];
        [vfl :@"V:|-7-[_colorCircle(6)]"];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_btnDelete attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    }
    return self;
}

- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    // Setting preferredMaxLayoutWidth on _textfield allows us
    // to calculate its height after word-wrapping.
    _textField.preferredMaxLayoutWidth = NSWidth(frame) - 36; // 36=16+20=left+right margin
}

- (CGFloat)height
{
    // The height of the textfield (which may have word-wrapped)
    // plus the height of the top and bottom marigns.
    return [_textField intrinsicContentSize].height + 6; // 6=3+3=top+bottom margin
}

@end
