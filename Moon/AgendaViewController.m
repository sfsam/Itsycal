//
//  AgendaViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/18/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "AgendaViewController.h"
#import "EventCenter.h"

static NSString *kColumnIdentifier    = @"Column";
static NSString *kDateCellIdentifier  = @"DateCell";
static NSString *kEventCellIdentifier = @"EventCell";

@interface AgendaDateCell : NSView
@property (nonatomic, weak) NSDate *date;
@end

@interface AgendaEventCell : NSView
@property (nonatomic, weak) EventInfo *eventInfo;
@property (nonatomic, readonly) CGFloat height;
@end

#pragma mark -
#pragma mark AgendaViewController

// =========================================================================
// AgendaViewController
// =========================================================================

@implementation AgendaViewController
{
    MoTableView *_tv;
    NSLayoutConstraint *_tvHeight;
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
    _tv.backgroundColor = [NSColor clearColor];
    _tv.hoverColor = [NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:0.1];
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
    
    // _tvHeight will be set after data loads so the view is the same height as the tableview.
    _tvHeight = [NSLayoutConstraint constraintWithItem:v attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0];
    [v addConstraint:_tvHeight];
    
    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [_tv reloadData];
}

- (void)reloadData
{
    [_tv reloadData];
    [_tv scrollRowToVisible:0];
    [[_tv enclosingScrollView] flashScrollers];
    [self sizeViewToFitTableview];
}

- (void)sizeViewToFitTableview
{
    NSInteger rows = [_tv numberOfRows];
    CGFloat height = 0;
    for (NSInteger row = 0; row < rows; ++row) {
        height += NSHeight([_tv rectOfRow:row]);
    }
    // Limit view height to a max of 500.
    _tvHeight.constant = MIN(height, 500);
    [self.view setNeedsLayout:YES];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.events == nil ? 0 : self.events.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSView *v = nil;
    id obj = self.events[row];
    
    if ([obj isKindOfClass:[NSDate class]]) {
        AgendaDateCell *cell = [_tv makeViewWithIdentifier:kDateCellIdentifier owner:self];
        if (cell == nil) cell = [AgendaDateCell new];
        cell.date = obj;
        v = cell;
    }
    else {
        AgendaEventCell *cell = [_tv makeViewWithIdentifier:kEventCellIdentifier owner:self];
        if (cell == nil) cell = [AgendaEventCell new];
        cell.eventInfo = obj;
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
        cell.eventInfo = obj;
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

- (void)tableView:(MoTableView *)tableView didHoverOverRow:(NSInteger)row
{
    if (row == -1 || [self tableView:_tv isGroupRow:row]) {
        row = -1;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaHoveredOverRow:)]) {
        [self.delegate agendaHoveredOverRow:row];
    }
}

@end

#pragma mark -
#pragma mark Agenda Date and Event cells

// =========================================================================
// AgendaDateCell
// =========================================================================

@implementation AgendaDateCell
{
    NSTextField *_textField;
    NSDateFormatter *_dateFormatter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.identifier = kDateCellIdentifier;
        _dateFormatter = [NSDateFormatter new];
        [_dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d M y"];
        _textField = [NSTextField new];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [NSFont fontWithName:@"Lucida Grande Bold" size:11];
        _textField.textColor = [NSColor colorWithWhite:0 alpha:0.9];
        _textField.editable = NO;
        _textField.bezeled = NO;
        _textField.drawsBackground = NO;
        _textField.stringValue = @"";
        [self addSubview:_textField];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[_textField]-8-|" options:0 metrics:nil views:@{@"_textField": _textField}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-2-[_textField]" options:0 metrics:nil views:@{@"_textField": _textField}]];
    }
    return self;
}

- (void)setDate:(NSDate *)date
{
    _date = date;
    _textField.stringValue = [_dateFormatter stringFromDate:date];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect r = self.bounds;
    [[NSColor colorWithRed:0.93 green:0.93 blue:0.94 alpha:1] set];
    NSRectFillUsingOperation(r, NSCompositeSourceOver);

    r.size.height -= 1;
    [[NSColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:1] set];
    NSRectFillUsingOperation(r, NSCompositeSourceOver);
}

@end

// =========================================================================
// AgendaEventCell
// =========================================================================

@implementation AgendaEventCell
{
    NSTextField *_textField;
    NSDateFormatter *_timeFormatter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.wantsLayer = YES; // for text to be smooth (why is this needed?)
        self.identifier = kEventCellIdentifier;
        _timeFormatter = [NSDateFormatter new];
        [_timeFormatter setLocalizedDateFormatFromTemplate:@"h:mm a"];
        _textField = [NSTextField new];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [NSFont fontWithName:@"Lucida Grande" size:11];
        _textField.textColor = [NSColor colorWithWhite:0 alpha:0.6];
        _textField.lineBreakMode = NSLineBreakByWordWrapping;
        _textField.editable = NO;
        _textField.bezeled = NO;
        _textField.drawsBackground = NO;
        _textField.stringValue = @"";
        [self addSubview:_textField];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-18-[_textField]-8-|" options:0 metrics:nil views:@{@"_textField": _textField}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-3-[_textField]" options:0 metrics:nil views:@{@"_textField": _textField}]];
    }
    return self;
}

- (void)setEventInfo:(EventInfo *)info
{
    _eventInfo = info;
    NSString *title = info == nil ? @"" : info.title;
    NSString *duration = @"";
    if (info.isAllDay == NO) {
        if (info.isStartDate == YES) {
            duration = [NSString stringWithFormat:@"\n%@", [_timeFormatter stringFromDate:info.startDate]];
        }
        else if (info.isEndDate == YES) {
            NSString *ends = NSLocalizedString(@"ends", @"Spanning event ends");
            duration = [NSString stringWithFormat:@"\n%@ %@", ends, [_timeFormatter stringFromDate:info.endDate]];
        }
        else {
            duration = [NSString stringWithFormat:@"\n%@ - %@", [_timeFormatter stringFromDate:info.startDate], [_timeFormatter stringFromDate:info.endDate]];
            // For events in "en" locales that use AM/PM format, remove
            // redundant AM or PM: "2 PM - 3 PM" => "2 - 3 PM"
            if ([duration hasSuffix:@"AM"]) {
                duration = [duration stringByReplacingOccurrencesOfString:@" AM - " withString:@" - "];
            }
            else if ([duration hasSuffix:@"PM"]) {
                duration = [duration stringByReplacingOccurrencesOfString:@" PM - " withString:@" - "];
            }
        }
        // If the locale is English and we are in 12 hour time,
        // remove :00 from the time. Effect is 3:00 PM -> 3 PM.
        NSString *localeIdentifier = [[NSLocale currentLocale] localeIdentifier];
        if ([localeIdentifier hasPrefix:@"en"]) {
            if ([[_timeFormatter dateFormat] rangeOfString:@"a"].location != NSNotFound) {
                duration = [duration stringByReplacingOccurrencesOfString:@":00" withString:@""];
            }
        }
    }
    NSString *string = [NSString stringWithFormat:@"%@%@", title, duration];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:string];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, title.length)];
    _textField.attributedStringValue = s;
}

- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    // Setting preferredMaxLayoutWidth on _textfield allows us
    // to calculate its height after word-wrapping.
    _textField.preferredMaxLayoutWidth = NSWidth(frame) - 26; // 26=18+8=left+right margin
}

- (CGFloat)height
{
    // The height of the textfield (which may have word-wrapped)
    // plus the height of the top and bottom marigns.
    return [_textField intrinsicContentSize].height + 6; // 6=3+3=top+bottom margin
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Since this view is layer-backed (so that font smoothing works
    // properly), we must fill with a clear color. Otherwise, the
    // view will be black.
    [[NSColor clearColor] set];
    NSRectFillUsingOperation(self.bounds, NSCompositeSourceOver);

    // Draw a colored circle
    [[self.eventInfo.calendarColor blendedColorWithFraction:0.3 ofColor:[NSColor whiteColor]] set];
    NSRect circleRect = NSMakeRect(6, NSMaxY(self.frame)-14, 8, 8);
    [[NSBezierPath bezierPathWithOvalInRect:circleRect] fill];
}

@end
