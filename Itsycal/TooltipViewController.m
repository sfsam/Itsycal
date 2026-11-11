//
//  TooltipViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "TooltipViewController.h"
#import "Themer.h"
#import "Sizer.h"

static NSString *kMoreCellIdentifier = @"TooltipMoreCell";

// The agenda's rows leave room at their sides for its hover highlight,
// which a tooltip doesn't have, so the rows extend this far past the
// tooltip's sides. They're inset a little from its top and bottom.
static const CGFloat kRowsOverhang = 3;
static const CGFloat kRowsInset = 2;

// The last row when not all the events fit.
@interface TooltipMoreRow : NSObject
@property (nonatomic) NSInteger count;
@end

@implementation TooltipMoreRow
@end

// "3 more", lined up with the events' titles.
@interface TooltipMoreCell : NSView
@property (nonatomic) NSTextField *textField;
- (void)updateSize;
@end

@implementation TooltipMoreCell
{
    NSLayoutConstraint *_leadingConstraint;
}

- (instancetype)init
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.identifier = kMoreCellIdentifier;
        _textField = [NSTextField labelWithString:@""];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.textColor = Theme.agendaEventDateTextColor;
        [self addSubview:_textField];
        _leadingConstraint = [_textField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor];
        _leadingConstraint.active = YES;
        [_textField.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-11].active = YES;
        [_textField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
        [self updateSize];
    }
    return self;
}

- (void)updateSize
{
    _textField.font = [NSFont systemFontOfSize:SizePref.fontSize];
    _leadingConstraint.constant = SizePref.agendaEventLeadingMargin;
}

@end

@interface TooltipViewController ()
@property (nonatomic, readonly) NSView *tooltipView;
- (NSSize)layoutEvents:(NSArray *)events maxHeight:(CGFloat)maxHeight;
@end

// =========================================================================
// TooltipDayContent
// =========================================================================

// One day's tooltip content: the day's events, which it puts in the
// shared view controller when the tooltip lays it out.
@interface TooltipDayContent : NSObject <TooltipContent>
@property (nonatomic, copy) NSArray *events;
@property (nonatomic) TooltipViewController *viewController;
@end

@implementation TooltipDayContent

- (NSView *)tooltipView
{
    return self.viewController.tooltipView;
}

- (NSSize)layoutTooltipViewWithMaxHeight:(CGFloat)maxHeight
{
    return [self.viewController layoutEvents:self.events maxHeight:maxHeight];
}

@end

#pragma mark -
#pragma mark TooltipViewController

// =========================================================================
// TooltipViewController
// =========================================================================

@implementation TooltipViewController
{
    NSView *_container; // the tooltip's content: self.view, inset
}

- (id<TooltipContent>)tooltipContentForEvents:(NSArray *)events
{
    TooltipDayContent *content = [TooltipDayContent new];
    content.events = events;
    content.viewController = self;
    return content;
}

- (void)loadView
{
    [super loadView];
    self.tv.enableHover = NO;
    _container = [NSView new];
    [_container addSubview:self.view];
}

- (void)viewDidLayout
{
    // Don't call super: the agenda sets its height there, through
    // preferredContentSize. The tooltip controller sizes this view
    // with -layoutEvents:maxHeight: instead.
}

#pragma mark -
#pragma mark Tooltip content

- (NSView *)tooltipView
{
    [self loadViewIfNeeded];
    return _container;
}

- (NSSize)layoutEvents:(NSArray *)events maxHeight:(CGFloat)maxHeight
{
    [self loadViewIfNeeded];
    CGFloat width = SizePref.tooltipWidth;
    NSView *rowsView = self.view;

    // Lay out at the tooltip's width first. The agenda measures rows
    // at the table's width.
    rowsView.frame = NSMakeRect(-kRowsOverhang, kRowsInset, width + 2 * kRowsOverhang, MAX(NSHeight(rowsView.frame), 1));
    [rowsView layoutSubtreeIfNeeded];

    self.events = events;
    NSMutableArray<NSNumber *> *heights = [NSMutableArray new];
    CGFloat total = 0;
    for (NSInteger row = 0; row < (NSInteger)events.count; row++) {
        CGFloat height = [self tableView:self.tv heightOfRow:row];
        [heights addObject:@(height)];
        total += height;
    }

    // If they don't all fit, show the events that fit, then a row
    // saying how many more there are.
    CGFloat available = maxHeight - 2 * kRowsInset;
    NSArray *rows = events;
    if (total > available) {
        CGFloat moreHeight = [self moreRowHeight];
        CGFloat used = 0;
        NSInteger shown = 0;
        while (shown < (NSInteger)events.count && used + heights[shown].doubleValue + moreHeight <= available) {
            used += heights[shown].doubleValue;
            shown++;
        }
        TooltipMoreRow *more = [TooltipMoreRow new];
        more.count = events.count - shown;
        rows = [[events subarrayWithRange:NSMakeRange(0, shown)] arrayByAddingObject:more];
        total = used + moreHeight;
    }
    self.events = rows;
    [self.tv reloadData];

    CGFloat height = ceil(total);
    rowsView.frame = NSMakeRect(-kRowsOverhang, kRowsInset, width + 2 * kRowsOverhang, height);
    _container.frame = NSMakeRect(0, 0, width, height + 2 * kRowsInset);
    [_container layoutSubtreeIfNeeded];
    [self scrollToTop];
    return _container.frame.size;
}

- (CGFloat)moreRowHeight
{
    // Like an event row with only a title: the text, 3 pt above and below.
    static NSTextField *measure = nil;
    if (measure == nil) {
        measure = [NSTextField labelWithString:@"0"];
    }
    measure.font = [NSFont systemFontOfSize:SizePref.fontSize];
    return ceil(measure.fittingSize.height) + 6;
}

#pragma mark -
#pragma mark TableView delegate/datasource

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id obj = self.events[row];
    if (![obj isKindOfClass:[TooltipMoreRow class]]) {
        return [super tableView:tableView viewForTableColumn:tableColumn row:row];
    }
    TooltipMoreCell *cell = [tableView makeViewWithIdentifier:kMoreCellIdentifier owner:self];
    if (cell == nil) cell = [TooltipMoreCell new];
    [cell updateSize];
    NSString *count = [NSNumberFormatter localizedStringFromNumber:@(((TooltipMoreRow *)obj).count) numberStyle:NSNumberFormatterDecimalStyle];
    NSString *format = NSLocalizedStringWithDefaultValue(@"%@ more events", nil, NSBundle.mainBundle, @"%@ more", @"Last row of a calendar day's tooltip when not all of the day's events fit: the number of events not shown, e.g. 3 more");
    cell.textField.stringValue = [NSString stringWithFormat:format, count];
    return cell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    if ([self.events[row] isKindOfClass:[TooltipMoreRow class]]) {
        return [self moreRowHeight];
    }
    return [super tableView:tableView heightOfRow:row];
}

@end
