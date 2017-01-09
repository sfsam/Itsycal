//
//  PrefsViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "PrefsViewController.h"
#import "Itsycal.h"
#import "MASShortcut/MASShortcutView.h"
#import "MASShortcut/MASShortcutView+Bindings.h"
#import "MoLoginItem/MoLoginItem.h"
#import "MoView.h"
#import "MoTextField.h"
#import "EventCenter.h"
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

@implementation PrefsViewController
{
    MoTextField *_title;
    NSButton *_login;
    NSButton *_checkUpdates;
    NSButton *_useOutlineIcon;
    NSButton *_showMonth;
    NSButton *_showDayOfWeek;
    NSTableView *_calendarsTV;
    NSPopUpButton *_daysPopup;
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    MoView *v = [MoView new];
 
    // App Icon
    NSImageView *appIcon = [NSImageView new];
    appIcon.translatesAutoresizingMaskIntoConstraints = NO;
    appIcon.image = [NSImage imageNamed:@"AppIcon"];
    [v addSubview:appIcon];

    // Convenience function for making text fields.
    MoTextField* (^txt)(NSString*) = ^MoTextField* (NSString *stringValue) {
        MoTextField *txt = [MoTextField new];
        txt.font = [NSFont systemFontOfSize:12];
        txt.translatesAutoresizingMaskIntoConstraints = NO;
        txt.editable = NO;
        txt.bezeled = NO;
        txt.drawsBackground = NO;
        txt.stringValue = stringValue;
        [v addSubview:txt];
        return txt;
    };

    // Convenience function for making checkboxes.
    NSButton* (^chkbx)(NSString *) = ^NSButton* (NSString *title) {
        NSButton *chkbx = [NSButton checkboxWithTitle:title target:self action:nil];
        chkbx.translatesAutoresizingMaskIntoConstraints = NO;
        chkbx.font = [NSFont systemFontOfSize:12];
        [v addSubview:chkbx];
        return chkbx;
    };
    
    // Title and version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    _title = txt([NSString stringWithFormat:@"Itsycal %@", infoDict[@"CFBundleShortVersionString"]]);
    _title.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    _title.textColor = [NSColor lightGrayColor];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:_title.stringValue];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor], NSFontAttributeName: [NSFont boldSystemFontOfSize:12]} range:NSMakeRange(0, 7)];
    _title.attributedStringValue = s;
    _title.target = self;
    _title.action = @selector(toggleTitle:);
    
    // Mowglii link
    MoTextField *link  = txt(@"mowglii.com/itsycal");
    link.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    link.linkEnabled = YES;
    
    // Checkboxes
    _login = chkbx(NSLocalizedString(@"Launch at login", @""));
    _login.action = @selector(launchAtLogin:);
    _checkUpdates = chkbx(NSLocalizedString(@"Automatically check for updates", @""));
    _useOutlineIcon = chkbx(NSLocalizedString(@"Use outline icon", @""));
    _showMonth = chkbx(NSLocalizedString(@"Show month in icon", @""));
    _showDayOfWeek = chkbx(NSLocalizedString(@"Show day of week in icon", @""));
    
    // Shortcut label
    MoTextField *shortcutLabel = txt(NSLocalizedString(@"Keyboard shortcut", @""));
    
    // Shortcut view
    MASShortcutView *shortcutView = [MASShortcutView new];
    shortcutView.translatesAutoresizingMaskIntoConstraints = NO;
    shortcutView.style = MASShortcutViewStyleTexturedRect;
    shortcutView.associatedUserDefaultsKey = kKeyboardShortcut;
    [v addSubview:shortcutView];
    
    // Calendars table view
    _calendarsTV = [NSTableView new];
    _calendarsTV.headerView = nil;
    _calendarsTV.allowsColumnResizing = NO;
    _calendarsTV.intercellSpacing = NSMakeSize(0, 0);
    _calendarsTV.dataSource = self;
    _calendarsTV.delegate = self;
    [_calendarsTV addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"SourcesAndCalendars"]];

    // Calendars enclosing scrollview
    NSScrollView *tvContainer = [NSScrollView new];
    tvContainer.translatesAutoresizingMaskIntoConstraints = NO;
    tvContainer.scrollerStyle = NSScrollerStyleLegacy;
    tvContainer.hasVerticalScroller = YES;
    tvContainer.documentView = _calendarsTV;
    [v addSubview:tvContainer];
    
    // Agenda days label
    MoTextField *daysLabel = txt(NSLocalizedString(@"Event list shows:", @""));
    
    // Agenda days popup
    _daysPopup = [NSPopUpButton new];
    _daysPopup.translatesAutoresizingMaskIntoConstraints = NO;
    [_daysPopup addItemsWithTitles:@[NSLocalizedString(@"No events", @""),
                                     NSLocalizedString(@"1 day", @""),
                                     NSLocalizedString(@"2 days", @""),
                                     NSLocalizedString(@"3 days", @""),
                                     NSLocalizedString(@"4 days", @""),
                                     NSLocalizedString(@"5 days", @""),
                                     NSLocalizedString(@"6 days", @""),
                                     NSLocalizedString(@"7 days", @""),]];
    [v addSubview:_daysPopup];
    
    // Copyright
    MoTextField *copyright = txt(infoDict[@"NSHumanReadableCopyright"]);
    copyright.textColor = [NSColor grayColor];
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*) = ^(NSString *format) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appIcon, _title, link, _login, _checkUpdates, _useOutlineIcon, _showMonth, _showDayOfWeek, shortcutLabel, shortcutView, tvContainer, daysLabel, _daysPopup, copyright)]];
    };
    vcon(@"V:|-m-[appIcon(32)]");
    vcon(@"H:|-m-[appIcon(32)]-[_title]-(>=m)-|");
    vcon(@"H:[appIcon]-[link]-(>=m)-|");
    vcon(@"V:|-20-[_title][link]");
    vcon(@"V:|-75-[_login]-[_checkUpdates]-16-[_useOutlineIcon]-[_showMonth]-[_showDayOfWeek]-20-[shortcutLabel]-3-[shortcutView(25)]-20-[tvContainer(170)]-[_daysPopup]-20-[copyright]-m-|");
    vcon(@"H:|-m-[_login]-(>=m)-|");
    vcon(@"H:|-m-[_checkUpdates]-(>=m)-|");
    vcon(@"H:|-m-[_useOutlineIcon]-(>=m)-|");
    vcon(@"H:|-m-[_showMonth]-(>=m)-|");
    vcon(@"H:|-m-[_showDayOfWeek]-(>=m)-|");
    vcon(@"H:|-(>=m)-[shortcutLabel]-(>=m)-|");
    vcon(@"H:|-m-[shortcutView(>=220)]-m-|");
    vcon(@"H:|-m-[tvContainer]-m-|");
    vcon(@"H:|-m-[daysLabel]-[_daysPopup]-(>=m)-|");
    vcon(@"H:|-(>=m)-[copyright]-(>=m)-|");
    
    // Leading-align title, link
    [v addConstraint:[NSLayoutConstraint constraintWithItem:_title attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:link attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    // Baselines of daysLabel and daysPopup
    [v addConstraint:[NSLayoutConstraint constraintWithItem:daysLabel attribute:NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem:_daysPopup attribute:NSLayoutAttributeBaseline multiplier:1 constant:0]];

    // Center shortcutLabel
    [v addConstraint:[NSLayoutConstraint constraintWithItem:shortcutLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    // Center copyright
    [v addConstraint:[NSLayoutConstraint constraintWithItem:copyright attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    
    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [_calendarsTV reloadData];
    _login.state = MOIsLoginItemEnabled() ? NSOnState : NSOffState;

    // Binding for Sparkle automatic update checks
    [_checkUpdates bind:@"value" toObject:[SUUpdater sharedUpdater] withKeyPath:@"automaticallyChecksForUpdates" options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for icon preferences
    [_useOutlineIcon bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kUseOutlineIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showMonth bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowMonthInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showDayOfWeek bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowDayOfWeekInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    // Bindings for agenda days
    [_daysPopup bind:@"selectedIndex" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDays] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    _calendarsTV.enabled = self.ec.calendarAccessGranted;
    _daysPopup.enabled = self.ec.calendarAccessGranted;
}

#pragma mark -
#pragma mark Toggle title

- (void)toggleTitle:(id)sender
{
    static BOOL toggle = NO;
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *version = toggle ? @"CFBundleShortVersionString": @"CFBundleVersion";
    NSString *str = [NSString stringWithFormat:@"Itsycal %@", infoDict[version]];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:str];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor], NSFontAttributeName: [NSFont boldSystemFontOfSize:12]} range:NSMakeRange(0, 7)];
    _title.attributedStringValue = s;
    toggle = !toggle;
}

#pragma mark -
#pragma mark Login item

- (void)launchAtLogin:(NSButton *)login
{
    MOEnableLoginItem(login.state == NSOnState);
}

#pragma mark -
#pragma mark Calendar

- (void)calendarClicked:(NSButton *)checkbox
{
    NSInteger row = checkbox.tag;
    BOOL selected = checkbox.state == NSOnState;
    [self.ec.sourcesAndCalendars[row] setSelected:selected];
    [self.ec updateSelectedCalendars];
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    // If access is denied, return 1 row for a message about granting access.
    return self.ec.calendarAccessGranted ? [self.ec.sourcesAndCalendars count] : 1;
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
    id obj = self.ec.sourcesAndCalendars[row];
    
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
        calendar.checkbox.state = info.selected == NSOnState;
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
        _textField = [NSTextField new];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [NSFont boldSystemFontOfSize:12];
        _textField.editable = NO;
        _textField.bezeled = NO;
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
        [_checkbox setButtonType:NSSwitchButton];
        [self addSubview:_checkbox];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[_checkbox]-4-|" options:0 metrics:nil views:@{@"_checkbox": _checkbox}]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-4-[_checkbox]" options:0 metrics:nil views:@{@"_checkbox": _checkbox}]];
    }
    return self;
}

@end
