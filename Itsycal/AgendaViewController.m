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

static NSString *kColumnIdentifier    = @"Column";
static NSString *kDateCellIdentifier  = @"DateCell";
static NSString *kEventCellIdentifier = @"EventCell";

@interface AgendaDateCell : NSView
@property (nonatomic) NSTextField *textField;
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
{
    NSDateFormatter *_dateFormatter;
    NSDateFormatter *_timeFormatter;
    NSDateIntervalFormatter *_intervalFormatter;
}

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
    _tv.backgroundColor = [NSColor whiteColor];
    _tv.hoverColor = [NSColor colorWithWhite:0.98 alpha:1];
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
    // Timezone changed notification
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemTimeZoneDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [_dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
        [_timeFormatter setTimeZone:[NSTimeZone localTimeZone]];
        [_intervalFormatter setTimeZone:[NSTimeZone localTimeZone]];
    }];
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

#pragma mark -
#pragma mark TableView delegate/datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.events == nil ? 0 : self.events.count;
}

- (NSView *)tableView:(MoTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSView *v = nil;
    id obj = self.events[row];
    
    if ([obj isKindOfClass:[NSDate class]]) {
        AgendaDateCell *cell = [_tv makeViewWithIdentifier:kDateCellIdentifier owner:self];
        if (cell == nil) cell = [AgendaDateCell new];
        cell.textField.stringValue = [self dateStringForDate:obj];
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
    // Keep a cell around for measuring height.
    static AgendaEventCell *cell = nil;
    if (cell == nil) { cell = [AgendaEventCell new]; }
    
    CGFloat height = 18; // AgendaDateCell height;
    id obj = self.events[row];
    if ([obj isKindOfClass:[EventInfo class]]) {
        cell.frame = NSMakeRect(0, 0, NSWidth(_tv.frame), 999); // only width is important here
        cell.textField.attributedStringValue = [self eventStringForInfo:obj];
        height = cell.height;
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

- (NSString *)dateStringForDate:(NSDate *)date
{
    if (!_dateFormatter) {
        _dateFormatter = [NSDateFormatter new];
    }
    // First, use _dateFormatter to get the day of the week (dow).
    _dateFormatter.timeZone = [NSTimeZone localTimeZone];
    _dateFormatter.dateFormat = @"EEEE";
    NSString *dow = [_dateFormatter stringFromDate:date];
    // If the date is today or tomorrow, use "Today" or "Tomorrow" as the dow.
    if (self.nsCal && ([self.nsCal isDateInToday:date] || [self.nsCal isDateInTomorrow:date])) {
        _dateFormatter.doesRelativeDateFormatting = YES;
        _dateFormatter.dateStyle = NSDateFormatterShortStyle;
        dow = [_dateFormatter stringFromDate:date];
    }
    // Next, use _dateFormatter to get the date string using the standard short style.
    _dateFormatter.doesRelativeDateFormatting = NO;
    _dateFormatter.dateStyle = NSDateFormatterShortStyle;
    // Finally, put them together...
    return [NSString stringWithFormat:@"%@ ∙ %@", dow, [_dateFormatter stringFromDate:date]];
}

- (NSAttributedString *)eventStringForInfo:(EventInfo *)info
{
    if (!_timeFormatter) {
        _timeFormatter = [NSDateFormatter new];
        _timeFormatter.dateStyle = NSDateFormatterNoStyle;
        _timeFormatter.timeStyle = NSDateFormatterShortStyle;
        _timeFormatter.timeZone  = [NSTimeZone localTimeZone];
    }
    if (!_intervalFormatter) {
        _intervalFormatter = [NSDateIntervalFormatter new];
        _intervalFormatter.dateStyle = NSDateIntervalFormatterNoStyle;
        _intervalFormatter.timeStyle = NSDateIntervalFormatterShortStyle;
        _intervalFormatter.timeZone  = [NSTimeZone localTimeZone];
    }
    NSString *title = info == nil ? @"" : info.event.title;
    NSString *duration = @"";
    if (info.isAllDay == NO) {
        if (info.isStartDate == YES) {
            duration = [NSString stringWithFormat:@"\n%@", [_timeFormatter stringFromDate:info.event.startDate]];
        }
        else if (info.isEndDate == YES) {
            NSString *ends = NSLocalizedString(@"ends", @"Spanning event ends");
            duration = [NSString stringWithFormat:@"\n%@ %@", ends, [_timeFormatter stringFromDate:info.event.endDate]];
        }
        else {
            duration = [NSString stringWithFormat:@"\n%@", [_intervalFormatter stringFromDate:info.event.startDate toDate:info.event.endDate]];
        }
        // If the locale is English and we are in 12 hour time,
        // remove :00 from the time. Effect is 3:00 PM -> 3 PM.
        if ([[[NSLocale currentLocale] localeIdentifier] hasPrefix:@"en"]) {
            if ([[_timeFormatter dateFormat] rangeOfString:@"a"].location != NSNotFound) {
                duration = [duration stringByReplacingOccurrencesOfString:@":00" withString:@""];
            }
        }
    }
    NSString *string = [NSString stringWithFormat:@"%@%@", title, duration];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:string];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, title.length)];
    return s;
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
        _textField = [NSTextField new];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = OSVersionIsAtLeast(10, 11, 0) ? [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold] : [NSFont fontWithName:@"Lucida Grande Bold" size:11];
        _textField.textColor = [NSColor colorWithWhite:0 alpha:0.9];
        _textField.editable = NO;
        _textField.bezeled = NO;
        _textField.drawsBackground = NO;
        _textField.stringValue = @"";
        [self addSubview:_textField];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[_textField]-4-|" options:0 metrics:nil views:@{@"_textField": _textField}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-2-[_textField]" options:0 metrics:nil views:@{@"_textField": _textField}]];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect r = self.bounds;
    [[NSColor colorWithRed:0.86 green:0.86 blue:0.88 alpha:1] set];
    NSRectFillUsingOperation(r, NSCompositeSourceOver);

    r.size.height -= 1;
    [[NSColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1] set];
    NSRectFillUsingOperation(r, NSCompositeSourceOver);
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
        _textField.font = OSVersionIsAtLeast(10, 11, 0) ? [NSFont systemFontOfSize:11] : [NSFont fontWithName:@"Lucida Grande" size:11];
        _textField.textColor = [NSColor colorWithWhite:0.5 alpha:1];
        _textField.lineBreakMode = NSLineBreakByWordWrapping;
        _textField.editable = NO;
        _textField.bezeled = NO;
        _textField.drawsBackground = NO;
        _textField.stringValue = @"";
        _btnDelete = [MoButton new];
        _btnDelete.image = [NSImage imageNamed:@"btnDel"];
        _btnDelete.backgroundColor = [NSColor colorWithDeviceWhite:0.98 alpha:1];
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

- (void)drawRect:(NSRect)dirtyRect
{
    // Draw a colored circle with a slightly darker border.
    [[self.eventInfo.event.calendar.color blendedColorWithFraction:0.1 ofColor:[NSColor blackColor]] set];
    NSRect circleRect = NSMakeRect(4, NSMaxY(self.frame)-14, 8, 8);
    [[NSBezierPath bezierPathWithOvalInRect:circleRect] fill];
    [[self.eventInfo.event.calendar.color blendedColorWithFraction:0.5 ofColor:[NSColor whiteColor]] set];
    circleRect = NSInsetRect(circleRect, 1, 1);
    [[NSBezierPath bezierPathWithOvalInRect:circleRect] fill];
}

@end
