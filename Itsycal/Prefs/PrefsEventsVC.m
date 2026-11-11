//
//  Created by Sanjay Madan on 10/5/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import "PrefsEventsVC.h"
#import "Itsycal.h"
#import "MoVFLHelper.h"
#import "EventCenter.h"

static NSString * const kSourceCellId = @"SourceCell";
static NSString * const kCalendarCellId = @"CalendarCell";
static NSString * const kButtonCellId = @"ButtonCell";

// Cell views for the Sources and Calendars table view.
@interface SourceCellView : NSView
@property (nonatomic) NSTextField *textField;
@end
@interface CalendarCellView : NSView
@property (nonatomic) NSButton *checkbox;
@end
@interface ButtonCellView : NSView
@property (nonatomic) NSButton *button;
@end

#pragma mark -
#pragma mark PrefsEventsVC

// =========================================================================
// PrefsEventsVC
// =========================================================================

@implementation PrefsEventsVC
{
    NSTableView *_calendarsTV;
    NSTextField *_agendaDaysLabel;
    NSPopUpButton *_agendaDaysPopup;
    NSButton *_showLocation;
    NSButton *_showDaysWithoutEvents;
    NSButton *_showCompletedReminders;
    NSButton *_showOverdueReminders;
    NSArray *_sourcesAndCalendars;
    EKAuthorizationStatus _remindersStatus;
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];

    // Convenience function for making checkboxes.
    NSButton* (^chkbx)(NSString *) = ^NSButton* (NSString *title) {
        NSButton *chkbx = [NSButton checkboxWithTitle:title target:self action:nil];
        [v addSubview:chkbx];
        return chkbx;
    };

    NSTextField *eventListLabel = [NSTextField labelWithString:NSLocalizedString(@"Event List", @"")];
    eventListLabel.font = [NSFont boldSystemFontOfSize:eventListLabel.font.pointSize-1];
    [v addSubview:eventListLabel];

    NSBox *separator = [NSBox new];
    separator.boxType = NSBoxSeparator;
    [v addSubview:separator];

    // Calendars table view
    _calendarsTV = [NSTableView new];
    _calendarsTV.headerView = nil;
    _calendarsTV.allowsColumnResizing = NO;
    _calendarsTV.intercellSpacing = NSMakeSize(0, 0);
    _calendarsTV.dataSource = self;
    _calendarsTV.delegate = self;
    _calendarsTV.style = NSTableViewStylePlain;
    [_calendarsTV addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"SourcesAndCalendars"]];

    // Calendars enclosing scrollview
    NSScrollView *tvContainer = [NSScrollView new];
    tvContainer.scrollerStyle = NSScrollerStyleLegacy;
    tvContainer.hasVerticalScroller = YES;
    tvContainer.documentView = _calendarsTV;
    tvContainer.borderType = NSLineBorder;
    [v addSubview:tvContainer];

    // Agenda days label
    _agendaDaysLabel = [NSTextField labelWithString:NSLocalizedString(@"Show:", @"Label for how many days the event list shows")];
    [v addSubview:_agendaDaysLabel];

    // Agenda days popup
    _agendaDaysPopup = [NSPopUpButton new];
    [_agendaDaysPopup addItemsWithTitles:@[NSLocalizedString(@"No events", @""),
                                     NSLocalizedString(@"1 day", @""),
                                     NSLocalizedString(@"2 days", @""),
                                     NSLocalizedString(@"3 days", @""),
                                     NSLocalizedString(@"4 days", @""),
                                     NSLocalizedString(@"5 days", @""),
                                     NSLocalizedString(@"6 days", @""),
                                     NSLocalizedString(@"7 days", @""),
                                     NSLocalizedString(@"14 days", @""),
                                     NSLocalizedString(@"31 days", @"")]];
    [_agendaDaysPopup.cell setAccessibilityTitleUIElement:_agendaDaysLabel.cell];
    [v addSubview:_agendaDaysPopup];

    // Checkboxes
    _showLocation = chkbx(NSLocalizedString(@"Show event location", @""));
    _showDaysWithoutEvents = chkbx(NSLocalizedString(@"Show days with no events", @""));
    _showCompletedReminders = chkbx(NSLocalizedString(@"Show completed reminders", @""));
    _showOverdueReminders = chkbx(NSLocalizedString(@"Show overdue reminders at the top", @"Settings checkbox for the agenda's Overdue section"));

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(eventListLabel, separator, tvContainer, _agendaDaysLabel, _agendaDaysPopup, _showLocation, _showDaysWithoutEvents, _showCompletedReminders, _showOverdueReminders)];
    [vfl :@"V:|-m-[tvContainer(170)]-m-[eventListLabel]-10-[_agendaDaysPopup]-m-[_showLocation]-[_showDaysWithoutEvents]-[_showCompletedReminders]-[_showOverdueReminders]-m-|"];
    [vfl :@"H:|-m-[eventListLabel]-[separator]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[tvContainer]-m-|"];
    [vfl :@"H:|-m-[_agendaDaysLabel]-[_agendaDaysPopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[_showLocation]-(>=m)-|"];
    [vfl :@"H:|-m-[_showDaysWithoutEvents]-(>=m)-|"];
    [vfl :@"H:|-m-[_showCompletedReminders]-(>=m)-|"];
    [vfl :@"H:|-m-[_showOverdueReminders]-(>=m)-|"];

    // Bindings for agenda days
    [_agendaDaysPopup bind:@"selectedIndex" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDays] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showLocation preference
    [_showLocation bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowLocation] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showDaysWithoutEvents preference
    [_showDaysWithoutEvents bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowDaysWithNoEventsInAgenda] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showCompletedReminders preference
    [_showCompletedReminders bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowCompletedReminders] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showOverdueReminders preference
    [_showOverdueReminders bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowOverdueReminders] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    _sourcesAndCalendars = [self.ec sourcesAndCalendars];
    _remindersStatus = self.ec.remindersAuthorizationStatus;
    [self updateControlsForAccess];
}

- (void)updateControlsForAccess
{
    // The event list shows events and reminders, so its options apply
    // if the user granted either kind of access.
    BOOL remindersGranted = _remindersStatus == EKAuthorizationStatusFullAccess;
    BOOL listShowsSomething = self.ec.calendarAccessGranted || remindersGranted;
    _agendaDaysLabel.textColor = listShowsSomething ? NSColor.labelColor : NSColor.disabledControlTextColor;
    _agendaDaysPopup.enabled = listShowsSomething;
    _showLocation.enabled = listShowsSomething;
    _showDaysWithoutEvents.enabled = listShowsSomething;
    _showCompletedReminders.enabled = remindersGranted;
    _showOverdueReminders.enabled = remindersGranted;
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    // We can properly measure row heights once the view has been laid out
    // and the width of the tableview is known. This tab may be appearing
    // for the first time, before any layout pass, so lay it out now.
    [self.view layoutSubtreeIfNeeded];
    [_calendarsTV reloadData];
}

#pragma mark -
#pragma mark Calendar

- (void)calendarClicked:(NSButton *)checkbox
{
    NSInteger index = checkbox.tag; // in _sourcesAndCalendars
    BOOL selected = checkbox.state == NSControlStateValueOn;
    CalendarInfo *info = _sourcesAndCalendars[index];
    NSString *calendarIdentifier = info.calendar.calendarIdentifier;
    [self.ec updateSelectedCalendarsForIdentifier:calendarIdentifier selected:selected];
    
    _sourcesAndCalendars = [self.ec sourcesAndCalendars];
    [_calendarsTV reloadData];
}

#pragma mark -
#pragma mark Reminders access

// The table's rows: if calendar access is denied, first a message about
// it (where calendars would be). Then the sources and calendars, and
// the reminder lists if reminders access is granted. Until it is, two
// rows follow: a Reminders heading, then a Show Reminders button (not
// asked yet) or a message (access denied). Reminders don't need
// calendar access, so these rows are there either way.
- (NSInteger)calendarsDeniedRowCount
{
    return self.ec.calendarAccessGranted ? 0 : 1;
}

- (BOOL)isCalendarsDeniedRow:(NSInteger)row
{
    return row < self.calendarsDeniedRowCount;
}

- (NSInteger)indexInSourcesAndCalendarsForRow:(NSInteger)row
{
    return row - self.calendarsDeniedRowCount;
}

- (BOOL)showsRemindersAccessRows
{
    return _remindersStatus != EKAuthorizationStatusFullAccess;
}

- (BOOL)isRemindersHeadingRow:(NSInteger)row
{
    return self.showsRemindersAccessRows && [self indexInSourcesAndCalendarsForRow:row] == _sourcesAndCalendars.count;
}

- (BOOL)isRemindersAccessRow:(NSInteger)row
{
    return self.showsRemindersAccessRows && [self indexInSourcesAndCalendarsForRow:row] == _sourcesAndCalendars.count + 1;
}

- (NSString *)calendarsDeniedMessage
{
    return NSLocalizedString(@"Calendar access denied.\n\nItsycal is more useful when it can display events from your calendars. You can change this setting in System Settings › Privacy & Security › Calendars", @"");
}

- (NSString *)remindersDeniedMessage
{
    return NSLocalizedString(@"Reminders access denied. You can change this setting in System Settings › Privacy & Security › Reminders", @"");
}

- (void)showRemindersClicked:(id)sender
{
    [self.ec requestRemindersAccessWithCompletion:^{
        self->_remindersStatus = self.ec.remindersAuthorizationStatus;
        [self updateControlsForAccess];
        self->_sourcesAndCalendars = [self.ec sourcesAndCalendars];
        [self->_calendarsTV reloadData];
        // Show the reminder lists (or the denied message) at the end.
        [self->_calendarsTV scrollRowToVisible:self->_calendarsTV.numberOfRows - 1];
    }];
}

#pragma mark -
#pragma mark TableView delegate/datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    // See -calendarsDeniedRowCount for the rows.
    return self.calendarsDeniedRowCount + [_sourcesAndCalendars count] + (self.showsRemindersAccessRows ? 2 : 0);
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    // The Show Reminders button is a regular push button. Measure
    // its cell once.
    if ([self isRemindersAccessRow:row] && _remindersStatus == EKAuthorizationStatusNotDetermined) {
        static CGFloat buttonRowHeight = 0;
        if (buttonRowHeight == 0) buttonRowHeight = [ButtonCellView new].fittingSize.height;
        return buttonRowHeight;
    }

    // Calculate the height of either the source title or the calendar title.
    // In the case of the source title, the available width is the full width
    // of the tablie view minus the left and right margins. In the case of the
    // calendar title, we have to make an adjustment to account for the space
    // occupied by the checkbox. We also add room for top and bottom margins
    // after the text height has been calculated.

    CGFloat tvWidth = NSWidth(_calendarsTV.frame);
    CGFloat textWidth = tvWidth - 4 - 4; // minus left & right margins
    NSString *str;
    NSFont *font = [NSFont boldSystemFontOfSize:12];

    id obj = nil;
    if ([self isCalendarsDeniedRow:row]) {
        str = [self calendarsDeniedMessage];
        font = [NSFont systemFontOfSize:12];
    } else if ([self isRemindersHeadingRow:row]) {
        str = NSLocalizedString(@"Reminders", @"Heading in Settings before reminders access is granted");
    } else if ([self isRemindersAccessRow:row]) {
        str = [self remindersDeniedMessage];
        font = [NSFont systemFontOfSize:12];
    } else if ([(obj = _sourcesAndCalendars[[self indexInSourcesAndCalendarsForRow:row]]) isKindOfClass:[CalendarInfo class]]) {
        str = ((CalendarInfo *)obj).calendar.title;
        textWidth -= 20.0; // account for checkbox
    } else {
        str = (NSString *)obj; // source title
    }
    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:str attributes:@{NSFontAttributeName: font}];
    CGRect attrStrRect = [attrStr boundingRectWithSize:CGSizeMake(textWidth, 10000) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
    return NSHeight(attrStrRect) + 4 + 4; // plus top & bottom margins
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
    return NO;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // If calendar access was denied, show a helpful message. We repurpose the
    // SourceCellView since it is just a textfield with nice margins.
    if ([self isCalendarsDeniedRow:row]) {
        SourceCellView *message = [tableView makeViewWithIdentifier:kSourceCellId owner:self];
        if (!message) message = [SourceCellView new];
        message.textField.lineBreakMode = NSLineBreakByWordWrapping;
        message.textField.font = [NSFont systemFontOfSize:12];
        message.textField.stringValue = [self calendarsDeniedMessage];
        return message;
    }
    
    // Before reminders access is granted, show a heading and then
    // a Show Reminders button, or a message if access was denied.
    if ([self isRemindersHeadingRow:row]) {
        SourceCellView *heading = [tableView makeViewWithIdentifier:kSourceCellId owner:self];
        if (!heading) heading = [SourceCellView new];
        heading.textField.font = [NSFont boldSystemFontOfSize:12];
        heading.textField.stringValue = NSLocalizedString(@"Reminders", @"Heading in Settings before reminders access is granted");
        return heading;
    }
    if ([self isRemindersAccessRow:row]) {
        if (_remindersStatus == EKAuthorizationStatusNotDetermined) {
            ButtonCellView *cell = [tableView makeViewWithIdentifier:kButtonCellId owner:self];
            if (!cell) cell = [ButtonCellView new];
            cell.button.title = NSLocalizedString(@"Show Reminders…", @"");
            cell.button.target = self;
            cell.button.action = @selector(showRemindersClicked:);
            return cell;
        }
        SourceCellView *message = [tableView makeViewWithIdentifier:kSourceCellId owner:self];
        if (!message) message = [SourceCellView new];
        message.textField.font = [NSFont systemFontOfSize:12];
        message.textField.stringValue = [self remindersDeniedMessage];
        return message;
    }

    // Show a list of sources and calendars with checkboxes.
    
    NSView *v = nil;
    NSInteger index = [self indexInSourcesAndCalendarsForRow:row];
    id obj = _sourcesAndCalendars[index];
    
    if ([obj isKindOfClass:[NSString class]]) {
        SourceCellView *source = [tableView makeViewWithIdentifier:kSourceCellId owner:self];
        if (!source) source = [SourceCellView new];
        source.textField.font = [NSFont boldSystemFontOfSize:12];
        source.textField.stringValue = (NSString *)obj;
        v = source;
    }
    else {
        CalendarInfo *info = obj;
        CalendarCellView *calendar = [tableView makeViewWithIdentifier:kCalendarCellId owner:self];
        if (!calendar) calendar = [CalendarCellView new];
        calendar.checkbox.target = self;
        calendar.checkbox.action = @selector(calendarClicked:);
        calendar.checkbox.state = info.selected == NSControlStateValueOn;
        calendar.checkbox.tag = index; // see -calendarClicked:
        calendar.checkbox.attributedTitle = [[NSAttributedString alloc] initWithString:info.calendar.title attributes:@{NSForegroundColorAttributeName: info.calendar.color, NSFontAttributeName: [NSFont boldSystemFontOfSize:12]}];
        v = calendar;
    }
    return v;
}

@end

#pragma mark -
#pragma mark Source and Calendar cell views

// =========================================================================
// SourceCellView
// =========================================================================

@implementation SourceCellView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.identifier = kSourceCellId;
        _textField = [NSTextField labelWithString:@""];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.lineBreakMode = NSLineBreakByWordWrapping;
        _textField.font = [NSFont boldSystemFontOfSize:12];
        _textField.stringValue = @"";
        [self addSubview:_textField];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[_textField]-4-|" options:0 metrics:nil views:@{@"_textField": _textField}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-4-[_textField]" options:0 metrics:nil views:@{@"_textField": _textField}]];
    }
    return self;
}

@end

// =========================================================================
// CalendarCellView
// =========================================================================

@implementation CalendarCellView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.identifier = kCalendarCellId;
        _checkbox = [NSButton new];
        _checkbox.translatesAutoresizingMaskIntoConstraints = NO;
        _checkbox.lineBreakMode = NSLineBreakByWordWrapping;
        [_checkbox setButtonType:NSButtonTypeSwitch];
        [self addSubview:_checkbox];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[_checkbox]-4-|" options:0 metrics:nil views:@{@"_checkbox": _checkbox}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-4-[_checkbox]" options:0 metrics:nil views:@{@"_checkbox": _checkbox}]];
    }
    return self;
}

@end

// =========================================================================
// ButtonCellView
// =========================================================================

@implementation ButtonCellView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.identifier = kButtonCellId;
        _button = [NSButton buttonWithTitle:NSLocalizedString(@"Show Reminders…", @"") target:nil action:nil];
        _button.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_button];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[_button]-(>=4)-|" options:0 metrics:nil views:@{@"_button": _button}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-4-[_button]-4-|" options:0 metrics:nil views:@{@"_button": _button}]];
    }
    return self;
}

@end
