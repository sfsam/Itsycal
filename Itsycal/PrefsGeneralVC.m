//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsGeneralVC.h"
#import "Itsycal.h"
#import "MoLoginItem.h"
#import "MoVFLHelper.h"
#import "EventCenter.h"
#import "MASShortcut/Shortcut.h"
#import "Sparkle/SUUpdater.h"

static NSString * const kSourceCellId = @"SourceCell";
static NSString * const kCalendarCellId = @"CalendarCell";

// Cell views for the Sources and Calendars table view.
@interface SourceCellView : NSView
@property (nonatomic) NSTextField *textField;
@end
@interface CalendarCellView : NSView
@property (nonatomic) NSButton *checkbox;
@end

#pragma mark -
#pragma mark PrefsViewController

// =========================================================================
// PrefsViewController
// =========================================================================

@implementation PrefsGeneralVC
{
    NSTextField *_title;
    NSButton *_login;
    NSButton *_checkUpdates;
    NSPopUpButton *_firstDayPopup;
    NSTableView *_calendarsTV;
    NSPopUpButton *_agendaDaysPopup;
    NSArray *_sourcesAndCalendars;
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];

    // Convenience function for making labels.
    NSTextField* (^label)(NSString*) = ^NSTextField* (NSString *stringValue) {
        NSTextField *txt = [NSTextField labelWithString:stringValue];
        [v addSubview:txt];
        return txt;
    };

    // Convenience function for making checkboxes.
    NSButton* (^chkbx)(NSString *) = ^NSButton* (NSString *title) {
        NSButton *chkbx = [NSButton checkboxWithTitle:title target:self action:nil];
        [v addSubview:chkbx];
        return chkbx;
    };
    
    // Checkboxes
    _login = chkbx(NSLocalizedString(@"Launch at login", @""));
    _login.action = @selector(launchAtLogin:);
    _checkUpdates = chkbx(NSLocalizedString(@"Automatically check for updates", @""));

    // First day of week label
    NSTextField *firstDayLabel = label(NSLocalizedString(@"First day of week:", @""));

    // First day of week popup
    _firstDayPopup = [NSPopUpButton new];
    [_firstDayPopup addItemsWithTitles:@[NSLocalizedString(@"Sunday", @""),
                                         NSLocalizedString(@"Monday", @""),
                                         NSLocalizedString(@"Tuesday", @""),
                                         NSLocalizedString(@"Wednesday", @""),
                                         NSLocalizedString(@"Thursday", @""),
                                         NSLocalizedString(@"Friday", @""),
                                         NSLocalizedString(@"Saturday", @"")]];
    [v addSubview:_firstDayPopup];
    
    // Shortcut label
    NSTextField *shortcutLabel = label(NSLocalizedString(@"Keyboard shortcut", @""));
    
    // Shortcut view
    MASShortcutView *shortcutView = [MASShortcutView new];
    [shortcutView setAssociatedUserDefaultsKey:kKeyboardShortcut withTransformerName:MASDictionaryTransformerName];
    [v addSubview:shortcutView];
    
    // Calendars table view
    _calendarsTV = [NSTableView new];
    _calendarsTV.headerView = nil;
    _calendarsTV.allowsColumnResizing = NO;
    _calendarsTV.intercellSpacing = NSMakeSize(0, 0);
    _calendarsTV.dataSource = self;
    _calendarsTV.delegate = self;
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
    if (@available(macOS 11.0, *)) {
        _calendarsTV.style = NSTableViewStylePlain;
    }
#endif
    [_calendarsTV addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"SourcesAndCalendars"]];

    // Calendars enclosing scrollview
    NSScrollView *tvContainer = [NSScrollView new];
    tvContainer.scrollerStyle = NSScrollerStyleLegacy;
    tvContainer.hasVerticalScroller = YES;
    tvContainer.documentView = _calendarsTV;
    [v addSubview:tvContainer];
    
    // Agenda days label
    NSTextField *agendaDaysLabel = label(NSLocalizedString(@"Event list shows:", @""));
    
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
    [v addSubview:_agendaDaysPopup];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(_login, _checkUpdates, firstDayLabel, _firstDayPopup, shortcutLabel, shortcutView, tvContainer, agendaDaysLabel, _agendaDaysPopup)];
    [vfl :@"V:|-m-[_login]-[_checkUpdates]-20-[_firstDayPopup]-20-[shortcutLabel]-3-[shortcutView(25)]-20-[tvContainer(170)]-[_agendaDaysPopup]-m-|"];
    [vfl :@"H:|-m-[_login]-(>=m)-|"];
    [vfl :@"H:|-m-[_checkUpdates]-(>=m)-|"];
    [vfl :@"H:|-m-[firstDayLabel]-[_firstDayPopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-(>=m)-[shortcutLabel]-(>=m)-|"];
    [vfl :@"H:|-m-[shortcutView(>=220)]-m-|"];
    [vfl :@"H:|-m-[tvContainer]-m-|"];
    [vfl :@"H:|-m-[agendaDaysLabel]-[_agendaDaysPopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];

    // Center shortcutLabel
    [v addConstraint:[NSLayoutConstraint constraintWithItem:shortcutLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    // Binding for Sparkle automatic update checks
    [_checkUpdates bind:@"value" toObject:[SUUpdater sharedUpdater] withKeyPath:@"automaticallyChecksForUpdates" options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    // Bindings for first day of week
    [_firstDayPopup bind:@"selectedIndex" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWeekStartDOW] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    // Bindings for agenda days
    [_agendaDaysPopup bind:@"selectedIndex" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDays] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    
    _sourcesAndCalendars = [self.ec sourcesAndCalendars];
    
    [_calendarsTV reloadData];

    // The API used to check the login item's state (LSSharedFileList) causes
    // errors for users who have network drives but are not connected to their
    // network (github.com/sfsam/Itsycal/issues/15). Give them an option to
    // disable this check.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DoNotCheckLoginItemStatus"] == NO) {
        _login.hidden = NO;
        _login.state = MOIsLoginItemEnabled() ? NSControlStateValueOn : NSControlStateValueOff;
    }
    else {
        _login.hidden = YES;
    }
    
    _calendarsTV.enabled = self.ec.calendarAccessGranted;
    _agendaDaysPopup.enabled = self.ec.calendarAccessGranted;
}

#pragma mark -
#pragma mark Login item

- (void)launchAtLogin:(NSButton *)login
{
    MOEnableLoginItem(login.state == NSControlStateValueOn);
}

#pragma mark -
#pragma mark Calendar

- (void)calendarClicked:(NSButton *)checkbox
{
    NSInteger row = checkbox.tag;
    BOOL selected = checkbox.state == NSControlStateValueOn;
    CalendarInfo *info = _sourcesAndCalendars[row];
    NSString *calendarIdentifier = info.calendar.calendarIdentifier;
    [self.ec updateSelectedCalendarsForIdentifier:calendarIdentifier selected:selected];
    
    _sourcesAndCalendars = [self.ec sourcesAndCalendars];
    [_calendarsTV reloadData];
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    // If access is denied, return 1 row for a message about granting access.
    return self.ec.calendarAccessGranted ? [_sourcesAndCalendars count] : 1;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    // If access is denied, row height is the height of the tableview
    // so we can show some helpful message text.
    return self.ec.calendarAccessGranted ? 24.0 : 170.0;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
    return NO;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // If calendar access was denied, show a helpful message.
    // We repurpose the SourceCellView for this since it is
    // basically just a textfield with nice margins.
    if (!self.ec.calendarAccessGranted) {
        SourceCellView *message = [tableView makeViewWithIdentifier:kSourceCellId owner:self];
        if (!message) message = [SourceCellView new];
        message.textField.lineBreakMode = NSLineBreakByWordWrapping;
        message.textField.font = [NSFont systemFontOfSize:12];
        message.textField.stringValue = NSLocalizedString(@"Calendar access denied.\n\nItsycal is more useful when it can display events from your calendars. You can change this setting in System Preferences › Security & Privacy › Privacy", @"");
        return message;
    }
    
    // Show a list of sources and calendars with checkboxes.
    
    NSView *v = nil;
    id obj = _sourcesAndCalendars[row];
    
    if ([obj isKindOfClass:[NSString class]]) {
        SourceCellView *source = [tableView makeViewWithIdentifier:kSourceCellId owner:self];
        if (!source) source = [SourceCellView new];
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
        calendar.checkbox.tag = row;
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
        _textField.font = [NSFont boldSystemFontOfSize:12];
        _textField.stringValue = @"";
        [self addSubview:_textField];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[_textField]-4-|" options:0 metrics:nil views:@{@"_textField": _textField}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-4-[_textField]-2-|" options:0 metrics:nil views:@{@"_textField": _textField}]];
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
        [_checkbox setButtonType:NSButtonTypeSwitch];
        [self addSubview:_checkbox];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[_checkbox]-4-|" options:0 metrics:nil views:@{@"_checkbox": _checkbox}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-4-[_checkbox]" options:0 metrics:nil views:@{@"_checkbox": _checkbox}]];
    }
    return self;
}

@end
