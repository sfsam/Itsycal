//
//  AgendaViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/18/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "Itsycal.h"
#import "AgendaViewController.h"
#import "AgendaPopoverVC.h"
#import "EventCenter.h"
#import "MoButton.h"
#import "MoPopover.h"
#import "MoThemeView.h"
#import "MoUtils.h"
#import "MoVFLHelper.h"
#import "Themer.h"
#import "Sizer.h"

static NSString *kColumnIdentifier    = @"Column";
static NSString *kDateCellIdentifier  = @"DateCell";
static NSString *kEventCellIdentifier = @"EventCell";
static NSString *kOverdueHeadingCellIdentifier = @"OverdueHeadingCell";
static const CGFloat kCompleteButtonSize = 18;
// A reminder's square sits this much lower than an event's dot,
// which looks better centered on the title.
static const CGFloat kReminderSquareNudge = 0.5;
// The gap between a completed reminder's outline and its fill.
static const CGFloat kReminderFillGap = 1;

@interface AgendaRowView : NSTableRowView
@property (nonatomic) BOOL isHovered;
@end

@interface AgendaDateCell : NSView
@property (nonatomic) NSTextField *dayTextField;
@property (nonatomic) NSTextField *DOWTextField;
@property (nonatomic, weak) NSDate *date;
@property (nonatomic) NSLayoutConstraint *dayTrailingConstraint;
- (void)sizeChanged:(id)sender;
@end

// The Overdue section's heading: a date cell with "Overdue" in place
// of the day of the week, and the number of overdue reminders and a
// disclosure chevron in place of the date, like a section of Finder's
// sidebar. Clicking it toggles the section; to VoiceOver it's a
// disclosure triangle.
@interface AgendaOverdueHeadingCell : AgendaDateCell
@property (nonatomic) NSImageView *chevron;
@property (nonatomic) NSTextField *titleTextField;
@property (nonatomic) BOOL expanded;
@property (nonatomic, copy) void (^toggleBlock)(void);
@end

@interface AgendaEventCell : NSView
@property (nonatomic) NSGridView *grid;
@property (nonatomic) NSTextField *titleTextField;
@property (nonatomic) NSTextField *locationTextField;
@property (nonatomic) NSTextField *durationTextField;
@property (nonatomic) MoButton *btnVideo;
@property (nonatomic) NSButton *btnComplete; // clear, over a reminder's square
@property (nonatomic, weak) EventInfo *eventInfo;
@property (nonatomic) BOOL dim;
@end

#pragma mark -
#pragma mark AgendaViewController

// =========================================================================
// AgendaViewController
// =========================================================================

@implementation AgendaViewController
{
    NSPopover *_popover;
    EventInfo *_popoverEventInfo; // event shown in _popover
}

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];

    // Calendars table view
    _tv = [MoTableView new];
    _tv.target = self;
    _tv.action = @selector(showPopover:);
    _tv.doubleAction = @selector(showCalendarApp:);
    _tv.menu = [NSMenu new];
    _tv.menu.delegate = self;
    _tv.headerView = nil;
    _tv.allowsColumnResizing = NO;
    _tv.intercellSpacing = NSMakeSize(0, 0);
    _tv.backgroundColor = NSColor.clearColor;
    _tv.floatsGroupRows = YES;
    _tv.refusesFirstResponder = YES;
    _tv.dataSource = self;
    _tv.delegate = self;
    _tv.style = NSTableViewStylePlain;
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

    // 😭😭😭 Hack alert!
    // On macOS Sonoma 14.3.1, window drawing (specifically the drawing done
    // by `ItsycalWindow`) is corrupted when:
    //   1. There are many events making the agenda too big to fit on-screen.
    //   2. The user has 2 monitors and switches to the smaller one.
    // I have no idea why setting `preferredContentSize` via a call to
    // `-performSelectorOnMainThread:withObject:waitUntilDone` works while
    // simply setting it here as we used to do no longer does.
    NSSize prefSize = NSMakeSize(NSWidth(_tv.frame), height);
    NSValue *value = [NSValue valueWithSize:prefSize];
    [self performSelectorOnMainThread:@selector(setPreferredContentSizeHack:) 
                           withObject:value waitUntilDone:NO];
}

- (void)setPreferredContentSizeHack:(NSValue *)value
{
    // See -viewDidLayout for why this is done here.
    self.preferredContentSize = value.sizeValue;
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
    [self scrollToTop];
    [[_tv enclosingScrollView] flashScrollers];
    [self.view setNeedsLayout:YES];
    [_popover close];
}

- (void)reloadDataKeepingScrollPosition
{
    // NSTableView keeps its scroll position when it reloads, and the
    // scroll view clamps it if the rows got shorter.
    [_tv reloadData];
    [self.view setNeedsLayout:YES];
    [_popover close];
}

- (void)scrollToTop
{
    [_tv scrollRowToVisible:0];
}

#pragma mark -
#pragma mark TableView context menu

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    // Invoked just before menu is to be displayed.
    // Show a context menu ONLY for non-group rows.
    [menu removeAllItems];
    NSInteger row = _tv.clickedRow;
    if (row < 0 || [self tableView:_tv isGroupRow:row] ||
        [self tableView:_tv isEmptyEventRow:row]) return;
    // Capture what each item acts on now, in representedObject.
    // self.events can be replaced (e.g. after a calendar change) while
    // the menu is open, so the actions must not look up the row again.
    EventInfo *info = self.events[row];
    NSMenuItem *item;
    // Like Calendar, a reminder can be checked off or unchecked
    // here, as well as by clicking its square, but not a future
    // occurrence of a repeating reminder.
    if (info.reminder.calendar.allowsContentModifications && !info.isFutureOccurrence) {
        NSString *title = info.reminder.isCompleted
            ? NSLocalizedString(@"Mark as Incomplete", nil)
            : NSLocalizedString(@"Mark as Completed", nil);
        item = [menu addItemWithTitle:title action:@selector(toggleReminderCompleted:) keyEquivalent:@""];
        item.representedObject = info;
        item.tag = !info.reminder.isCompleted; // what to set it to
    }
    item = [menu addItemWithTitle:NSLocalizedString(@"Open Calendar", nil) action:@selector(showCalendarApp:) keyEquivalent:@""];
    item.representedObject = [self dateForEventRow:row];
    item = [menu addItemWithTitle:NSLocalizedString(@"Copy", nil) action:@selector(copyEventToPasteboard:) keyEquivalent:@""];
    item.representedObject = [self pasteboardTextForEventRow:row];
    // Only offer links that can be shared, not app links like zoommtg://.
    NSString *scheme = info.meetingURL.scheme.lowercaseString;
    if ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) {
        item = [menu addItemWithTitle:NSLocalizedString(@"Copy Meeting Link", nil) action:@selector(copyMeetingURLToPasteboard:) keyEquivalent:@""];
        item.representedObject = info.meetingURL;
    }
    if (info.event.calendar.allowsContentModifications) {
        item = [menu addItemWithTitle:NSLocalizedString(@"Delete…", nil) action:@selector(deleteEvent:) keyEquivalent:@""];
        item.representedObject = info;
    }
    // Never show menu item images, whatever the system configuration.
    for (NSMenuItem *menuItem in menu.itemArray) {
        menuItem.preferredImageVisibility = NSMenuItemImageVisibilityHidden;
    }
}

#pragma mark -
#pragma mark Copy

- (void)copyEventToPasteboard:(NSMenuItem *)sender
{
    // Text was captured when the menu was built. See -menuNeedsUpdate:.
    NSString *eventText = sender.representedObject;
    if (eventText == nil) return;
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] writeObjects:@[eventText]];
}

- (NSString *)pasteboardTextForEventRow:(NSInteger)row
{
    AgendaEventCell *cell = [_tv viewAtColumn:0 row:row makeIfNecessary:NO];

    if (cell == nil) return nil; // should not happen

    EventInfo *info = cell.eventInfo;
    NSString *duration = DateRangeString(info.startDate, info.endDate, info.isRealAllDay);
    NSString *eventText = [NSString stringWithFormat:@"%@\n%@\n%@%@",
                           cell.titleTextField.stringValue,
                           duration,
                           cell.locationTextField.stringValue,
                           cell.locationTextField.stringValue.length > 0 ? @"\n" : @""];
    return eventText;
}

- (void)copyMeetingURLToPasteboard:(NSMenuItem *)sender
{
    // URL was captured when the menu was built. See -menuNeedsUpdate:.
    NSURL *url = sender.representedObject;
    if (url == nil) return;
    // Provide both URL and plain-text types. Writing the NSURL alone
    // omits plain text, so it won't paste into plain-text fields.
    NSPasteboardItem *item = [NSPasteboardItem new];
    [item setString:url.absoluteString forType:NSPasteboardTypeURL];
    [item setString:url.absoluteString forType:NSPasteboardTypeString];
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] writeObjects:@[item]];
}

#pragma mark -
#pragma mark TableView click actions

- (void)showPopoverForRow:(NSInteger)row
{
    if (row == -1 || [self tableView:_tv isGroupRow:row] ||
        [self tableView:_tv isEmptyEventRow:row]) return;

    if (!_popover) {
        AgendaPopoverVC *popoverVC = [AgendaPopoverVC new];
        __weak AgendaViewController *weakSelf = self;
        popoverVC.deleteHandler = ^{
            AgendaViewController *strongSelf = weakSelf;
            if (strongSelf == nil) return;
            [strongSelf deleteEventInfo:strongSelf->_popoverEventInfo];
        };
        _popover = [MoPopover new];
        _popover.contentViewController = popoverVC;
        _popover.behavior = NSPopoverBehaviorTransient;
        _popover.animates = NO;
        // Enable coloring the full background including the arrow.
        // See AgendaPopoverVC -loadView.
        _popover.hasFullSizeContent = YES;
    }
    
    AgendaEventCell *cell = [_tv viewAtColumn:0 row:row makeIfNecessary:NO];
    
    if (!cell) return; // should never happen
    
    AgendaPopoverVC *popoverVC = (AgendaPopoverVC *)_popover.contentViewController;
    [popoverVC populateWithEventInfo:cell.eventInfo];
    // Keep the event itself, not its row. self.events can be replaced
    // while the popover is open. See -deleteEventInfo:.
    _popoverEventInfo = cell.eventInfo;
    
    NSRect positionRect = NSInsetRect([_tv rectOfRow:row], 8, 0);
    [_popover showRelativeToRect:positionRect ofView:_tv preferredEdge:NSRectEdgeMinX];
    // Force a layout pass now that the view is in a window. This ensures
    // preferredMaxLayoutWidth is set on wrapping NSTextField labels before
    // fittingSize is queried, preventing an incorrectly short popover on
    // first display (second display would have been correct without this).
    [popoverVC.view layoutSubtreeIfNeeded];
    [_popover setContentSize:popoverVC.size];
    [popoverVC popoverDidShow];
}

- (void)showPopover:(id)sender
{
    // Clicking the Overdue heading shows or hides the section.
    if (_tv.clickedRow != -1 && [self.events[_tv.clickedRow] isKindOfClass:[AgendaOverdueHeading class]]) {
        [self toggleOverdueSection];
        return;
    }
    if (_tv.clickedRow == -1 || [self tableView:_tv isGroupRow:_tv.clickedRow] ||
        [self tableView:_tv isEmptyEventRow:_tv.clickedRow]) return;

    [self showPopoverForRow:_tv.clickedRow];
}

- (void)showCalendarApp:(id)sender
{
    NSDate *clickedDate = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        // Date was captured when the menu was built. See -menuNeedsUpdate:.
        clickedDate = [(NSMenuItem *)sender representedObject];
    } else {
        // Double click; clickedRow is current.
        if (_tv.clickedRow == -1 || [self tableView:_tv isGroupRow:_tv.clickedRow]) return;
        clickedDate = [self dateForEventRow:_tv.clickedRow];
    }
    if (!clickedDate) return; // should never happen
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaShowCalendarAppAtDate:)]) {
        [self.delegate agendaShowCalendarAppAtDate:clickedDate];
    }
}

- (NSDate *)dateForEventRow:(NSInteger)row
{
    // The day the event row (an EventInfo row) is listed under. We use
    // this instead of the event's startDate because spanning events
    // might start on a different date from the one that was clicked.
    id obj = self.events[row];
    return [obj isKindOfClass:[EventInfo class]] ? ((EventInfo *)obj).date : nil;
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
        if ([(NSDate*)obj hasNoEvents]) {
            cell.dayTextField.textColor = NSColor.tertiaryLabelColor;
            cell.DOWTextField.textColor = NSColor.tertiaryLabelColor;
        }
        v = cell;
    }
    else if ([obj isKindOfClass:[AgendaOverdueHeading class]]) {
        AgendaOverdueHeading *heading = obj;
        AgendaOverdueHeadingCell *cell = [_tv makeViewWithIdentifier:kOverdueHeadingCellIdentifier owner:self];
        if (cell == nil) cell = [AgendaOverdueHeadingCell new];
        NSString *count = [NSNumberFormatter localizedStringFromNumber:@(heading.count) numberStyle:NSNumberFormatterDecimalStyle];
        cell.expanded = heading.expanded;
        cell.dayTextField.stringValue = count;
        // Red, like overdue reminders' titles, which a collapsed
        // section hides.
        cell.dayTextField.textColor = Theme.agendaOverdueTextColor;
        cell.titleTextField.textColor = Theme.agendaDOWTextColor;
        cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%@, %@", @"VoiceOver label for the agenda's Overdue heading: Overdue, then the number of overdue reminders"), cell.titleTextField.stringValue, count];
        __weak typeof(self) weakSelf = self;
        cell.toggleBlock = ^{ [weakSelf toggleOverdueSection]; };
        v = cell;
    }
    else {
        EventInfo *info = obj;
        AgendaEventCell *cell = [_tv makeViewWithIdentifier:kEventCellIdentifier owner:self];
        if (!cell) cell = [AgendaEventCell new];
        [self populateEventCell:cell withInfo:info];
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
    
    CGFloat height = dateCell.fittingSize.height;
    id obj = self.events[row];
    if ([obj isKindOfClass:[EventInfo class]]) {
        eventCell.frame = NSMakeRect(0, 0, NSWidth(_tv.frame), 999); // only width is important here
        [self populateEventCell:eventCell withInfo:obj];
        height = eventCell.fittingSize.height;
    }
    return height;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    // Date headings and the Overdue heading, which float.
    id obj = self.events[row];
    return [obj isKindOfClass:[NSDate class]] || [obj isKindOfClass:[AgendaOverdueHeading class]];
}

- (void)toggleOverdueSection
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaWantsToToggleOverdueSection)]) {
        [self.delegate agendaWantsToToggleOverdueSection];
    }
}

- (BOOL)tableView:(NSTableView *)tableView isEmptyEventRow:(NSInteger)row
{
    id obj = self.events[row];
    return ([obj isKindOfClass:[EventInfo class]] &&
            ((EventInfo *)obj).item == nil);
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return NO; // disable selection
}

- (void)tableView:(MoTableView *)tableView didHoverOverRow:(NSInteger)hoveredRow
{
    BOOL showPopoverOnHover = [[NSUserDefaults standardUserDefaults] boolForKey:kShowEventPopoverOnHover];
    if (hoveredRow == -1 || [self tableView:_tv isGroupRow:hoveredRow] ||
        [self tableView:_tv isEmptyEventRow:hoveredRow]) {
        if (showPopoverOnHover && hoveredRow != -1) {
            [_popover close];
        }
        hoveredRow = -1;
    }
    for (NSInteger row = 0; row < [_tv numberOfRows]; row++) {
        if (![self tableView:_tv isGroupRow:row]) {
            BOOL isEmptyEventRow = [self tableView:_tv isEmptyEventRow:row];
            BOOL isHovered = (row == hoveredRow && !isEmptyEventRow);
            AgendaRowView *rowView = [_tv rowViewAtRow:row makeIfNecessary:NO];
            rowView.isHovered = isHovered;
            if (showPopoverOnHover && isHovered) {
                [self showPopoverForRow:hoveredRow];
            }
        }
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaHoveredOverRow:)]) {
        [self.delegate agendaHoveredOverRow:hoveredRow];
    }
}

#pragma mark -
#pragma mark Delete event

- (void)deleteEvent:(NSMenuItem *)sender
{
    [self deleteEventInfo:sender.representedObject];
}

- (void)deleteEventInfo:(EventInfo *)info
{
    // Act on a captured EventInfo, not a row index. self.events can be
    // replaced while the menu or popover is open.
    if (info.event == nil || !info.event.calendar.allowsContentModifications) return;
    // The event may have changed or been deleted elsewhere since the menu
    // or popover opened. Refresh it; NO means it no longer exists.
    if (![info.event refresh]) return;
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaWantsToDeleteEvent:)]) {
        [self.delegate agendaWantsToDeleteEvent:info.event];
    }
}

#pragma mark -
#pragma mark Complete reminder

- (void)toggleReminderCompleted:(id)sender
{
    // Act on a captured EventInfo, not a row index. See -deleteEventInfo:.
    // The sender is a reminder's square (a button in its cell) or a
    // context menu item. Its tag is what to set the reminder to,
    // decided from what the user saw: 1 to check off, 0 to uncheck.
    EventInfo *info = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        info = [(NSMenuItem *)sender representedObject];
    } else if ([[sender superview] isKindOfClass:[AgendaEventCell class]]) {
        info = ((AgendaEventCell *)[sender superview]).eventInfo;
    }
    BOOL completed = [sender tag] != 0;
    EKReminder *reminder = info.reminder;
    if (reminder == nil || !reminder.calendar.allowsContentModifications) return;
    // The reminder may have changed or been deleted elsewhere since
    // the agenda loaded. Refresh it; NO means it no longer exists.
    if (![reminder refresh]) return;
    // If it was already changed elsewhere to what the user wants,
    // there's nothing to do. Don't flip it the other way. Also do
    // nothing if it's no longer due on the date the user saw: checking
    // off a repeating reminder moves it, still incomplete, to its next
    // due date, so a quick second click would check that one off too.
    if (reminder.isCompleted == completed || !ReminderIsDue(reminder, info.dueDate)) return;
    if (self.delegate && [self.delegate respondsToSelector:@selector(agendaWantsToSetReminder:completed:)]) {
        [self.delegate agendaWantsToSetReminder:reminder completed:completed];
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

// A reminder's due date for the Overdue section, e.g. "Oct 19" or
// "Oct 19, 9 AM", with the year if it isn't this year.
- (NSString *)dueDateStringForInfo:(EventInfo *)info
{
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) formatter = [NSDateFormatter new];
    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.locale = NSLocale.currentLocale;
    BOOL thisYear = [self.nsCal isDate:info.dueDate equalToDate:NSDate.date toUnitGranularity:NSCalendarUnitYear];
    NSString *template = thisYear ? @"MMMd" : @"yMMMd";
    if (!info.isAllDay) template = [template stringByAppendingString:@"jmm"];
    [formatter setLocalizedDateFormatFromTemplate:template];
    return StringByStrippingZeroMinutes([formatter stringFromDate:info.dueDate]);
}

- (void)populateEventCell:(AgendaEventCell *)cell withInfo:(EventInfo *)info
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

    // There are no events on this date.
    if (!info.item) {
        cell.eventInfo = nil;
        cell.dim = YES;
        cell.titleTextField.stringValue = @"";
        cell.titleTextField.textColor = NSColor.tertiaryLabelColor;
        [cell.grid rowAtIndex:1].hidden = YES; // hide location row
        [cell.grid rowAtIndex:2].hidden = YES; // hide duration row
        cell.btnVideo.enabled = NO;
        cell.btnVideo.hidden = YES;
        cell.btnComplete.hidden = YES;
        return;
    }

    // Clicking a reminder's square checks it off (or unchecks it), in
    // the agenda but not in tooltips, if its list can be changed. Only
    // a repeating reminder's current occurrence can be checked off.
    cell.btnComplete.hidden = !(info.reminder.calendar.allowsContentModifications &&
                                !info.isFutureOccurrence &&
                                [self.identifier isEqualToString:@"AgendaVC"]);
    cell.btnComplete.target = self;
    cell.btnComplete.action = @selector(toggleReminderCompleted:);
    cell.btnComplete.tag = !info.reminder.isCompleted; // what to set it to
    cell.btnComplete.accessibilityValue = @(info.reminder.isCompleted);

    NSString *title = @"";
    NSString *location = @"";
    NSString *duration = @"";
    timeFormatter.timeZone  = [NSTimeZone localTimeZone];
    intervalFormatter.timeZone = nil; // Force tz update on macOS 10.13
    intervalFormatter.timeZone  = [NSTimeZone localTimeZone];
    // Needed to pick up 12/24 hr time system preference change:
    intervalFormatter.locale = DateIntervalFormatterLocale();
    
    cell.eventInfo = info;

    if (info && info.item) {
        if (info.item.title) {
            // If title has newlines or stretches of whitespace, compress
            // them into a single space.
            title = [[info.item.title componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@" "];
        }
        if (info.location) location = info.location;
    }
    
    // Hide location row IF !self.showLocation OR there's no location string.
    [cell.grid rowAtIndex:1].hidden = (!self.showLocation || location.length == 0);
    
    // Hide duration row for all day events, except in the Overdue
    // section, where it shows the due date.
    [cell.grid rowAtIndex:2].hidden = info.isAllDay && !info.isInOverdueSection;
    
    if (info.isInOverdueSection) {
        // Not under a day's heading, so show the due date (and time).
        duration = [self dueDateStringForInfo:info];
    }
    else if (info.isAllDay == NO) {
        if (info.reminder) {
            // A reminder with a time shows when it's due.
            duration = [timeFormatter stringFromDate:info.dueDate];
        }
        else if (info.isStartDate == YES) {
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
        duration = StringByStrippingZeroMinutes(duration);
    }

    // Virtual meeting button.
    cell.btnVideo.enabled = NO;
    cell.btnVideo.hidden = info.meetingURL ? NO : YES;
    cell.btnVideo.actionBlock = nil;
    cell.btnVideo.contentTintColor = nil;

    cell.titleTextField.stringValue = title;
    cell.titleTextField.textColor = Theme.agendaEventTextColor;
    cell.locationTextField.stringValue = location;
    cell.locationTextField.textColor = Theme.agendaEventDateTextColor;
    cell.durationTextField.stringValue = duration;
    cell.durationTextField.textColor = Theme.agendaEventDateTextColor;

    // If event's endDate is today and is past, dim event.
    cell.dim = NO;
    if (info.event && !info.isStartDate && !info.isAllDay
        && [self.nsCal isDateInToday:info.event.endDate]
        && [NSDate.date compare:info.event.endDate] == NSOrderedDescending) {
        cell.titleTextField.textColor = Theme.agendaEventDateTextColor;
        cell.dim = YES;
    }

    // Dim a repeating reminder's later occurrences, as Calendar does.
    // Only the current occurrence can be overdue, even if a later one
    // is already in the past (when the current one is overdue).
    if (info.isFutureOccurrence) {
        cell.titleTextField.textColor = Theme.agendaEventDateTextColor;
        cell.dim = YES;
    }
    // An incomplete reminder is overdue once its due time has
    // passed or, if it has no time, once its day has passed.
    // Show its title in red, as Reminders shows its due date.
    else if (info.reminder && !info.reminder.isCompleted) {
        NSDate *now = NSDate.date;
        NSDate *deadline = info.isAllDay ? [self.nsCal startOfDayForDate:now] : now;
        if ([info.dueDate compare:deadline] == NSOrderedAscending) {
            cell.titleTextField.textColor = Theme.agendaOverdueTextColor;
        }
    }
    
    // Enable the zoom button 15 minutes prior to event start until end.
    // If the user prefers, button can remain enabled indefinitely.
    // Only events have meetings (and a meetingURL).
    NSDate *fifteenMinutesPrior = info.event ? MeetingJoinableThreshold(info.event, self.nsCal) : nil;
    if (info.meetingURL && !info.event.isAllDay
        && [fifteenMinutesPrior compare:NSDate.date] == NSOrderedAscending
        && ([NSDate.date compare:info.event.endDate] == NSOrderedAscending
            || [NSUserDefaults.standardUserDefaults boolForKey:kEnableMeetingButtonIndefinitely])) {
        cell.btnVideo.enabled = YES;
        cell.btnVideo.contentTintColor = Theme.todayCellColor;
        cell.btnVideo.actionBlock = ^{
            [NSWorkspace.sharedWorkspace openURL:AppLinkForMeetingURL(info.meetingURL)];
        };
    }
}

#pragma mark -
#pragma mark Dim past events

- (void)dimEventsIfNecessary
{
    // If the user has the window showing, reload the agenda cells.
    // This will redraw the events, dimming if necessary.
    // This also enables/disables zoom buttons if necessary
    // depending on whether a virtual meeting is in progress.
    if (self.view.window.isVisible) {
        [_tv reloadData];
    }
}

#pragma mark -
#pragma mark Click first active Zoom button

- (BOOL)clickFirstActiveZoomButton
{
    for (NSInteger row = 0; row < _tv.numberOfRows; row++) {
        NSView *view = [_tv viewAtColumn:0 row:row makeIfNecessary:NO];
        if ([view isKindOfClass:[AgendaEventCell class]]) {
            AgendaEventCell *cell = (AgendaEventCell *)view;
            if (cell.btnVideo.enabled) {
                [cell.btnVideo performClick:self];
                return YES;
            }
        }
    }
    return NO;
}

@end

#pragma mark -
#pragma mark Agenda Row View

// =========================================================================
// AgendaOverdueHeading
// =========================================================================

// Properties auto-synthesized.
@implementation AgendaOverdueHeading @end

// =========================================================================
// AgendaRowView
// =========================================================================

@implementation AgendaRowView

- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    if (self.isHovered) {
        [Theme.agendaHoverColor set];
        NSRect rect = NSInsetRect(self.bounds, 8, 1);
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
        _dayTextField.font = [NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightSemibold];
        _dayTextField.textColor = Theme.agendaDayTextColor;
        [_dayTextField setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        _DOWTextField = [NSTextField labelWithString:@""];
        _DOWTextField.translatesAutoresizingMaskIntoConstraints = NO;
        _DOWTextField.font = [NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightSemibold];
        _DOWTextField.textColor = Theme.agendaDOWTextColor;

        [self addSubview:_dayTextField];
        [self addSubview:_DOWTextField];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_dayTextField, _DOWTextField)];
        [vfl :@"H:|-10-[_DOWTextField]-(>=4)-[_dayTextField]" :NSLayoutFormatAlignAllLastBaseline];
        [vfl :@"V:|-6-[_dayTextField]-1-|"];
        _dayTrailingConstraint = [self.trailingAnchor constraintEqualToAnchor:_dayTextField.trailingAnchor constant:10];
        _dayTrailingConstraint.active = YES;
        
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sizeChanged:(id)sender
{
    _dayTextField.font = [NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightSemibold];
    _DOWTextField.font = [NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightSemibold];
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Must be opaque so rows can scroll under it.
    [Theme.mainBackgroundColor set];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
    NSRect r = NSMakeRect(10, self.bounds.size.height - 4, self.bounds.size.width - 20, 1);
    [Theme.agendaDividerColor set];
    NSRectFillUsingOperation(r, NSCompositingOperationSourceOver);
}

@end

// =========================================================================
// AgendaOverdueHeadingCell
// =========================================================================

@implementation AgendaOverdueHeadingCell {
    NSLayoutConstraint *_chevronWidthConstraint;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.identifier = kOverdueHeadingCellIdentifier;
        // The date cell's day-of-week label gives way to "Overdue". Its
        // date label (dayTextField) shows the count, moved over to make
        // room for the chevron after it.
        self.DOWTextField.hidden = YES;
        _chevron = [NSImageView new];
        _chevron.translatesAutoresizingMaskIntoConstraints = NO;
        _chevron.imageScaling = NSImageScaleNone;
        _chevron.imageAlignment = NSImageAlignRight;
        _chevron.accessibilityElement = NO;
        _titleTextField = [NSTextField labelWithString:NSLocalizedString(@"Overdue", @"Heading of the agenda's section of overdue reminders")];
        _titleTextField.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_chevron];
        [self addSubview:_titleTextField];
        [_titleTextField.leadingAnchor constraintEqualToAnchor:self.DOWTextField.leadingAnchor].active = YES;
        [_titleTextField.lastBaselineAnchor constraintEqualToAnchor:self.dayTextField.lastBaselineAnchor].active = YES;
        // Right-aligned, a little inside the end of the divider.
        [_chevron.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-11].active = YES;
        [_chevron.centerYAnchor constraintEqualToAnchor:_titleTextField.centerYAnchor].active = YES;
        // A fixed width, so the count doesn't move when the chevron turns.
        _chevronWidthConstraint = [_chevron.widthAnchor constraintEqualToConstant:SizePref.fontSize];
        _chevronWidthConstraint.active = YES;
        self.dayTrailingConstraint.active = NO;
        [self.dayTextField.trailingAnchor constraintEqualToAnchor:_chevron.leadingAnchor constant:-2].active = YES;
        [self.dayTextField.leadingAnchor constraintGreaterThanOrEqualToAnchor:_titleTextField.trailingAnchor constant:4].active = YES;
        // To VoiceOver, the cell is the disclosure triangle, labeled
        // with the title and count; its labels aren't read again.
        self.accessibilityElement = YES;
        self.accessibilityRole = NSAccessibilityDisclosureTriangleRole;
        _titleTextField.accessibilityElement = NO;
        self.dayTextField.accessibilityElement = NO;
        [self updateFontsAndChevron];
    }
    return self;
}

- (void)setExpanded:(BOOL)expanded
{
    _expanded = expanded;
    [self updateFontsAndChevron];
    self.accessibilityValue = @(expanded);
}

- (void)updateFontsAndChevron
{
    _titleTextField.font = [NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightSemibold];
    _chevronWidthConstraint.constant = SizePref.fontSize;
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:SizePref.fontSize - 2 weight:NSFontWeightSemibold];
    _chevron.image = [[NSImage imageWithSystemSymbolName:(_expanded ? @"chevron.down" : @"chevron.right") accessibilityDescription:nil] imageWithSymbolConfiguration:config];
    _chevron.contentTintColor = Theme.agendaEventDateTextColor;
}

- (void)sizeChanged:(id)sender
{
    [super sizeChanged:sender];
    [self updateFontsAndChevron];
}

- (BOOL)accessibilityPerformPress
{
    if (self.toggleBlock) self.toggleBlock();
    return YES;
}

@end

// =========================================================================
// AgendaEventCell
// =========================================================================

@implementation AgendaEventCell {
    NSLayoutConstraint *_gridLeadingConstraint;
    NSLayoutConstraint *_btnCompleteLeadingConstraint;
    NSLayoutConstraint *_btnCompleteTopConstraint;
}

- (instancetype)init
{
    // Convenience function for making labels.
    NSTextField* (^label)(void) = ^NSTextField* () {
        NSTextField *lbl = [NSTextField labelWithString:@""];
        lbl.font = [NSFont systemFontOfSize:SizePref.fontSize];
        lbl.lineBreakMode = NSLineBreakByTruncatingTail;
        lbl.allowsExpansionToolTips = YES;
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
        
        _btnVideo = [MoButton new];
        _btnVideo.bordered = 0;
        _btnVideo.image = [NSImage imageNamed:SizePref.videoImageName];
        _btnVideo.image.template = YES;
        
        /*
         Outer box = self
         Middle box = grid
         Innermost box = durationGrid
         a = _gridLeadingConstraint
         +------------------------------------------+
         |     |                                    |
         |     3                                    |
         |     |                                    |
         |   +---------------------------------+    |
         |-a-|[titleTextField]                 |-11-|
         |   |[locationTextField]              |    |
         |   |+-------------------------------+|    |
         |   ||[durationTextField], [btnVideo]||    |
         |   |+-------------------------------+|    |
         |   +---------------------------------+    |
         |     |                                    |
         |     3                                    |
         |     |                                    |
         +------------------------------------------+
         */
        
        NSGridView *durationGrid = [NSGridView gridViewWithViews:@[@[_durationTextField, _btnVideo]]];
        durationGrid.rowSpacing = 0;
        [durationGrid setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        _grid = [NSGridView gridViewWithViews:@[@[_titleTextField],
                                                @[_locationTextField],
                                                @[durationGrid]]];
        _grid.translatesAutoresizingMaskIntoConstraints = NO;
        _grid.rowSpacing = 0;
        [self addSubview:_grid];
        
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_grid)];
        [vfl :@"H:[_grid]-11-|"];
        [vfl :@"V:|-3-[_grid]-3-|"];
        
        CGFloat leadingConstant = SizePref.agendaEventLeadingMargin;
        _gridLeadingConstraint = [_grid.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:leadingConstant];
        _gridLeadingConstraint.active = YES;
        
        [_btnVideo.centerYAnchor constraintEqualToAnchor:_durationTextField.centerYAnchor].active = YES;
        
        // A clear button over a reminder's square, which -drawRect:
        // draws. It's bigger than the square so it's easier to hit.
        _btnComplete = [NSButton new];
        _btnComplete.title = @"";
        _btnComplete.bordered = NO;
        _btnComplete.transparent = YES;
        _btnComplete.translatesAutoresizingMaskIntoConstraints = NO;
        _btnComplete.accessibilityElement = YES;
        _btnComplete.accessibilityRole = NSAccessibilityCheckBoxRole;
        _btnComplete.accessibilityLabel = NSLocalizedString(@"Completed", @"Accessibility label for a reminder's checkbox in the event list");
        [self addSubview:_btnComplete];
        [_btnComplete.widthAnchor constraintEqualToConstant:kCompleteButtonSize].active = YES;
        [_btnComplete.heightAnchor constraintEqualToConstant:kCompleteButtonSize].active = YES;
        _btnCompleteLeadingConstraint = [_btnComplete.leadingAnchor constraintEqualToAnchor:self.leadingAnchor];
        _btnCompleteTopConstraint = [_btnComplete.topAnchor constraintEqualToAnchor:self.topAnchor];
        _btnCompleteLeadingConstraint.active = YES;
        _btnCompleteTopConstraint.active = YES;
        [self positionCompleteButton];

        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)positionCompleteButton
{
    // Center the button on the square. See -drawRect: for where the
    // square is: x = 11, and its top is fontSize + 2 - side, plus
    // the nudge, from the top of the cell.
    CGFloat side = SizePref.agendaDotWidth;
    CGFloat squareTop = SizePref.fontSize + 2 - side + kReminderSquareNudge;
    _btnCompleteLeadingConstraint.constant = 11 + side/2 - kCompleteButtonSize/2;
    _btnCompleteTopConstraint.constant = squareTop + side/2 - kCompleteButtonSize/2;
}

- (void)sizeChanged:(id)sender
{
    [self positionCompleteButton];
    _gridLeadingConstraint.constant = SizePref.agendaEventLeadingMargin;
    _btnVideo.image = [NSImage imageNamed:SizePref.videoImageName];
    _btnVideo.image.template = YES;
    _titleTextField.font = [NSFont systemFontOfSize:SizePref.fontSize];
    _locationTextField.font = [NSFont systemFontOfSize:SizePref.fontSize];
    _durationTextField.font = [NSFont systemFontOfSize:SizePref.fontSize];
}

- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    // Setting preferredMaxLayoutWidth allows us to calculate height
    // after word-wrapping.
    // margins = leading + trailing margins
    CGFloat margins = _gridLeadingConstraint.constant + 5;
    _titleTextField.preferredMaxLayoutWidth = NSWidth(frame) - margins;
    _locationTextField.preferredMaxLayoutWidth = NSWidth(frame) - margins;
    _durationTextField.preferredMaxLayoutWidth = NSWidth(frame) - margins;
}

- (void)setDim:(BOOL)dim {
    if (_dim != dim) {
        _dim = dim;
        [self setNeedsDisplay:YES];
    }
}

- (NSImage *)pendingPatternImage
{
    static NSImage *patternImage = nil;
    if (!patternImage) {
        patternImage = [NSImage imageWithSize:NSMakeSize(8, 8) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            [Theme.pendingBackgroundColor set];
            NSBezierPath *p = [NSBezierPath new];
            [p moveToPoint:NSMakePoint(-2, 2)];
            [p lineToPoint:NSMakePoint(6, 10)];
            [p moveToPoint:NSMakePoint(10, 6)];
            [p lineToPoint:NSMakePoint(2, -2)];
            [p setLineWidth:3];
            [p stroke];
            return YES;
        }];
    }
    return patternImage;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // There are no events on this date. Draw a dash.
    if (!self.eventInfo) {
        [NSColor.tertiaryLabelColor set];
        CGFloat diameter = SizePref.agendaDotWidth/3.0;
        CGFloat y = (NSHeight(self.bounds) - diameter)/2.0;
        NSRect rect = NSMakeRect(11, y, diameter * 3.0, diameter);
        CGFloat radius = diameter/2.0;
        [[NSBezierPath bezierPathWithRoundedRect:rect
                                         xRadius:radius
                                         yRadius:radius] fill];
        return;
    }

    // Draw a reminder as a rounded square in its list's color, like
    // a checkbox. It's open when incomplete and filled when completed.
    // (An open circle is a tentative or pending event; see below.)
    // The square is stroked on the dot's outline, like those circles,
    // so it's as wide as they are: the dot's width plus the line width.
    // A completed reminder's square also has a smaller filled square
    // inset inside it, with a gap of kReminderFillGap.
    if (self.eventInfo.reminder) {
        CGFloat side = SizePref.agendaDotWidth;
        CGFloat radius = side / 4.0;
        CGFloat lineWidth = 1.5;
        NSRect rect = NSMakeRect(11, NSHeight(self.bounds) - (SizePref.fontSize + 2) - kReminderSquareNudge, side, side);
        CGFloat alpha = self.dim ? 0.5 : 1;
        [[self.eventInfo.reminder.calendar.color colorWithAlphaComponent:alpha] set];
        NSBezierPath *box = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
        box.lineWidth = lineWidth;
        [box stroke];
        if (self.eventInfo.reminder.isCompleted) {
            // The stroke's inner edge is half the line width inside rect.
            CGFloat inset = lineWidth / 2.0 + kReminderFillGap;
            CGFloat fillRadius = MAX(radius - inset, 0.5);
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, inset, inset) xRadius:fillRadius yRadius:fillRadius] fill];
        }
        return;
    }

    // Draw a pattern background for events that are pending
    // participation acceptance. Inset and radius match the
    // hover values in AgendaRowView -drawBackgroundInRect:.
    BOOL isTentative = [[self.eventInfo.event valueForKey:@"participationStatus"] integerValue] == EKParticipantStatusTentative;
    BOOL isPending = [[self.eventInfo.event valueForKey:@"participationStatus"] integerValue] == EKParticipantStatusPending;
    if (self.eventInfo.event.hasAttendees && isPending) {
        [[NSColor colorWithPatternImage:[self pendingPatternImage]] set];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 8, 1) xRadius:5 yRadius:5] fill];
    }
    // Draw colored dot. Dot is elongated for all-day events.
    // Stroke for tentative and pending events, otherwise fill.
    CGFloat alpha = self.dim ? 0.5 : 1;
    CGFloat x = 11;
    CGFloat yOffset = SizePref.fontSize + 2;
    CGFloat dotWidthX = SizePref.agendaDotWidth;
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
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, NSHeight(self.bounds) - yOffset, dotWidthX, dotWidthY) xRadius:radius yRadius:radius];
    if (self.eventInfo.event.hasAttendees && (isTentative || isPending)) {
        p.lineWidth = 1.5;
        [p stroke];
    } else {
        [p fill];
    }
}

@end
