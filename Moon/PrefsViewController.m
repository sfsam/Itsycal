//
//  PrefsViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "PrefsViewController.h"
#import "Itsycal.h"
#import "MASShortcutView.h"
#import "MASShortcutView+Bindings.h"
#import "MoView.h"
#import "MoTextField.h"
#import "EventCenter.h"

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
    NSImageView *appIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
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
    
    // Title and version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    _title = txt([NSString stringWithFormat:@"Itsycal %@", infoDict[@"CFBundleShortVersionString"]]);
    _title.font = [NSFont boldSystemFontOfSize:13];
    _title.textColor = [NSColor lightGrayColor];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:_title.stringValue];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, 7)];
    _title.attributedStringValue = s;
    _title.target = self;
    _title.action = @selector(toggleTitle:);
    
    // Mowglii link
    MoTextField *link  = txt(@"mowglii.com/itsycal");
    link.font = [NSFont boldSystemFontOfSize:12];
    link.linkEnabled = YES;
    
    // Login checkbox
    _login = [NSButton new];
    _login.translatesAutoresizingMaskIntoConstraints = NO;
    _login.title = NSLocalizedString(@"Launch at login", @"");
    _login.font = [NSFont systemFontOfSize:12];
    _login.target = self;
    _login.action = @selector(launchAtLogin:);
    [_login setButtonType:NSSwitchButton];
    [v addSubview:_login];
    
    // Show month checkbox
    _showMonth = [NSButton new];
    _showMonth.translatesAutoresizingMaskIntoConstraints = NO;
    _showMonth.title = NSLocalizedString(@"Show month in icon", @"");
    _showMonth.font = [NSFont systemFontOfSize:12];
    _showMonth.target = self;
    _showMonth.action = @selector(showMonthInIcon:);
    [_showMonth setButtonType:NSSwitchButton];
    [v addSubview:_showMonth];
    
    // Show day-of-week checkbox
    _showDayOfWeek = [NSButton new];
    _showDayOfWeek.translatesAutoresizingMaskIntoConstraints = NO;
    _showDayOfWeek.title = NSLocalizedString(@"Show day of week in icon", @"");
    _showDayOfWeek.font = [NSFont systemFontOfSize:12];
    _showDayOfWeek.target = self;
    _showDayOfWeek.action = @selector(showDayOfWeekInIcon:);
    [_showDayOfWeek setButtonType:NSSwitchButton];
    [v addSubview:_showDayOfWeek];
    
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
    _daysPopup.target = self;
    _daysPopup.action = @selector(showEventDays:);
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
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appIcon, _title, link, _login, _showMonth, _showDayOfWeek, shortcutLabel, shortcutView, tvContainer, daysLabel, _daysPopup, copyright)]];
    };
    vcon(@"V:|-m-[appIcon(64)]");
    vcon(@"H:|-m-[appIcon(64)]-[_title]-(>=m)-|");
    vcon(@"H:[appIcon]-[link]-(>=m)-|");
    vcon(@"V:|-36-[_title]-1-[link]");
    vcon(@"V:|-110-[_login]-[_showMonth]-[_showDayOfWeek]-20-[shortcutLabel]-3-[shortcutView(25)]-20-[tvContainer(170)]-[_daysPopup]-20-[copyright]-m-|");
    vcon(@"H:|-m-[_login]-(>=m)-|");
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
    _login.state = [self isLoginItemEnabled] ? NSOnState : NSOffState;
    _showMonth.state = [[NSUserDefaults standardUserDefaults] boolForKey:kShowMonthInIcon];
    _showDayOfWeek.state = [[NSUserDefaults standardUserDefaults] boolForKey:kShowDayOfWeekInIcon];
    NSInteger days = [[NSUserDefaults standardUserDefaults] integerForKey:kShowEventDays];
    [_daysPopup selectItemAtIndex:MIN(MAX(days, 0), 7)]; // days is in range 0..7
    
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
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, 7)];
    _title.attributedStringValue = s;
    toggle = !toggle;
}

- (void)showMonthInIcon:(NSButton *)showMonthCheckbox
{
    BOOL showMonth = showMonthCheckbox.state;
    [[NSUserDefaults standardUserDefaults] setBool:showMonth forKey:kShowMonthInIcon];
    [[NSNotificationCenter defaultCenter] postNotificationName:kShowMonthInIconPreferenceChanged object:nil];
}

- (void)showDayOfWeekInIcon:(NSButton *)showDayOfWeekCheckbox
{
    BOOL showDayOfWeek = showDayOfWeekCheckbox.state;
    [[NSUserDefaults standardUserDefaults] setBool:showDayOfWeek forKey:kShowDayOfWeekInIcon];
    [[NSNotificationCenter defaultCenter] postNotificationName:kShowDayOfWeekInIconPreferenceChanged object:nil];
}

#pragma mark -
#pragma mark Login item

- (void)launchAtLogin:(NSButton *)login
{
    [self enableLoginItem:login.state == NSOnState];
}

- (BOOL)isLoginItemEnabled
{
    BOOL isEnabled = NO;
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef) {
        UInt32 seedValue;
        NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
        for (id item in loginItems) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
            if (pathURL && [pathURL.path hasPrefix:appPath]) {
                isEnabled = YES;
                break;
            }
        }
        CFRelease(loginItemsRef);
    }
    return isEnabled;
}

- (void)enableLoginItem:(BOOL)enable;
{
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef) {
        if (enable) {
            // We call LSSharedFileListInsertItemURL to insert the item at the bottom of Login Items list.
            CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
            if (item != NULL) CFRelease(item);
        }
        else {
            // Grab the contents of the shared file list (LSSharedFileListItemRef objects)
            // and pop it in an array so we can iterate through it to find our item.
            UInt32 seedValue;
            NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
            for (id item in loginItems) {
                LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
                NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
                if (pathURL && [pathURL.path hasPrefix:appPath]) {
                    LSSharedFileListItemRemove(loginItemsRef, itemRef); // Deleting the item
                }
            }
        }
        CFRelease(loginItemsRef);
    }
}

#pragma mark -
#pragma mark Calendar

- (void)showEventDays:(id)sender
{
    NSInteger days = [_daysPopup indexOfItem:_daysPopup.selectedItem];
    [[NSUserDefaults standardUserDefaults] setInteger:days forKey:kShowEventDays];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDaysToShowPreferenceChanged object:nil];
}

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
