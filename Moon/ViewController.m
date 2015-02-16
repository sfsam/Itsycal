//
//  ViewController.m
//  Itsycal2
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "ViewController.h"
#import "Itsycal.h"
#import "ItsycalWindow.h"
#import "MoCalendar.h"
#import "SBCalendar.h"
#import "PrefsViewController.h"
#import "MoButton.h"

@implementation ViewController
{
    MoCalendar    *_moCal;
    NSCalendar    *_nsCal;
    NSStatusItem  *_statusItem;
    MoButton      *_btnAdd, *_btnCal, *_btnOpt, *_btnPin;
    NSRect         _menuItemFrame, _screenFrame;
    
    NSWindowController *_prefsWC;
}

- (void)dealloc
{
    if (_statusItem) {
        [self removeStatusItem];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    
    // MoCalendar
    _moCal = [MoCalendar new];
    _moCal.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:_moCal];
    
    // Convenience function to config buttons.
    MoButton* (^btn)(NSString*, NSString*, NSString*, SEL) = ^MoButton* (NSString *imageName, NSString *tip, NSString *key, SEL action) {
        MoButton *btn = [MoButton new];
        [btn setButtonType:NSMomentaryChangeButton];
        [btn setBordered:NO];
        [btn setTarget:self];
        [btn setAction:action];
        [btn setToolTip:tip];
        [btn setImage:[NSImage imageNamed:imageName]];
        [btn setImagePosition:NSImageOnly];
        [btn setKeyEquivalent:key];
        [btn setKeyEquivalentModifierMask:NSCommandKeyMask];
        [btn setTranslatesAutoresizingMaskIntoConstraints:NO];
        [v addSubview:btn];
        return btn;
    };

    // Add, Calendar.app and Options buttons
    _btnAdd = btn(@"btnAdd", NSLocalizedString(@"New Event... ⌘N", @""), @"n", @selector(addCalendarEvent:));
    _btnCal = btn(@"btnCal", NSLocalizedString(@"Open Calendar... ⌘O", @""), @"o", @selector(showCalendarApp:));
    _btnOpt = btn(@"btnOpt", NSLocalizedString(@"Options", @""), @"", @selector(showOptionsMenu:));
    _btnPin = btn(@"btnPin", NSLocalizedString(@"Pin Itsycal... P", @""), @"p", @selector(pin:));
    _btnPin.keyEquivalentModifierMask = 0;
    _btnPin.alternateImage = [NSImage imageNamed:@"btnPinAlt"];
    [_btnPin setButtonType:NSToggleButton];
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*, NSLayoutFormatOptions) = ^(NSString *format, NSLayoutFormatOptions opts) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:opts metrics:nil views:NSDictionaryOfVariableBindings(_moCal, _btnAdd, _btnCal, _btnOpt, _btnPin)]];
    };
    vcon(@"H:|[_moCal]|", 0);
    vcon(@"V:|[_moCal]-26-|", 0);
    vcon(@"V:[_moCal]-8-[_btnOpt]", 0);
    vcon(@"H:|-6-[_btnAdd]-(>=0)-[_btnPin]-8-[_btnCal]-8-[_btnOpt]-6-|", NSLayoutFormatAlignAllCenterY);
    
    self.view = v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Menu extra notifications
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraIsActive:) name:ItsycalExtraIsActiveNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraClicked:) name:ItsycalExtraClickedNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraMoved:) name:ItsycalExtraDidMoveNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraWillUnload:) name:ItsycalExtraWillUnloadNotification object:nil];

    // The order of the statements is important!

    _nsCal = [NSCalendar autoupdatingCurrentCalendar];
    
    MoDate today = self.todayDate;
    [_moCal setTodayDate:today];
    [_moCal setSelectedDate:today];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dayChanged:) name:NSCalendarDayChangedNotification object:nil];

    [self createStatusItem];
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalIsActiveNotification object:nil userInfo:@{@"day": @(_moCal.todayDate.day)} deliverImmediately:YES];
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self.itsycalWindow makeFirstResponder:_moCal];
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _btnPin.state = [defaults boolForKey:kPinItsycal] ? NSOnState : NSOffState;
    _moCal.showWeeks = [defaults boolForKey:kShowWeeks];
    _moCal.weekStartDOW = [defaults integerForKey:kWeekStartDOW];
    
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenFrame:_screenFrame];
}

#pragma mark -
#pragma mark Keyboard & button actions

- (void)keyDown:(NSEvent *)theEvent
{
    NSString *charsIgnoringModifiers = [theEvent charactersIgnoringModifiers];
    if (charsIgnoringModifiers.length != 1) return;
    NSUInteger flags = [theEvent modifierFlags];
    BOOL noFlags = !(flags & (NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask | NSControlKeyMask));
    BOOL cmdFlag = (flags & NSCommandKeyMask) &&  !(flags & (NSShiftKeyMask | NSAlternateKeyMask | NSControlKeyMask));
    unichar keyChar = [charsIgnoringModifiers characterAtIndex:0];
    
    if (keyChar == 'w' && noFlags) {
        [self showWeeks:self];
    }
    else if (keyChar == ',' && cmdFlag) {
        [self showPrefs:self];
    }
    else {
        [super keyDown:theEvent];
    }
}

- (void)addCalendarEvent:(id)sender
{
    NSLog(@"%@", [(NSButton *)sender toolTip]);
}

- (void)showCalendarApp:(id)sender
{
    // Use the Scripting Bridge to open Calendar.app on the
    // date selected in our calendar.
    
    SBCalendarApplication *calendarApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.iCal"];
    if (calendarApp == nil) {
        NSString *message = NSLocalizedString(@"The Calendar application could not be found.", @"Alert box message when we fail to launch the Calendar application");
        NSAlert *alert = [NSAlert new];
        alert.messageText = message;
        alert.alertStyle = NSCriticalAlertStyle;
        [alert runModal];
        return;
    }
    NSDateComponents *comp = [NSDateComponents new];
    comp.year  = _moCal.selectedDate.year;
    comp.month = _moCal.selectedDate.month+1; // _moCal zero-indexes month
    comp.day   = _moCal.selectedDate.day;
    [calendarApp viewCalendarAt:[_nsCal dateFromComponents:comp]];
}

- (void)showOptionsMenu:(id)sender
{
    NSMenu *optMenu = [[NSMenu alloc] initWithTitle:@"Options Menu"];
    NSInteger i = 0;
    NSMenuItem *item;
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"Show calendar weeks", @"") action:@selector(showWeeks:) keyEquivalent:@"w" atIndex:i++];
    item.state = _moCal.showWeeks ? NSOnState : NSOffState;
    item.keyEquivalentModifierMask = 0;
    
    // Week Start submenu
    NSMenu *weekStartMenu = [[NSMenu alloc] initWithTitle:@"Week Start Menu"];
    NSInteger i2 = 0;
    for (NSString *d in @[NSLocalizedString(@"Sunday", @""), NSLocalizedString(@"Monday", @""),
                          NSLocalizedString(@"Tuesday", @""), NSLocalizedString(@"Wednesday", @""),
                          NSLocalizedString(@"Thursday", @""), NSLocalizedString(@"Friday", @""),
                          NSLocalizedString(@"Saturday", @"")]) {
        [weekStartMenu insertItemWithTitle:d action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    }
    [[weekStartMenu itemAtIndex:_moCal.weekStartDOW] setState:NSOnState];
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"First day of week", @"") action:NULL keyEquivalent:@"" atIndex:i++];
    item.submenu = weekStartMenu;
    
    [optMenu insertItem:[NSMenuItem separatorItem] atIndex:i++];
    [optMenu insertItemWithTitle:NSLocalizedString(@"Preferences...", @"") action:@selector(showPrefs:) keyEquivalent:@"," atIndex:i++];
    [optMenu insertItem:[NSMenuItem separatorItem] atIndex:i++];
    [optMenu insertItemWithTitle:NSLocalizedString(@"Quit Itsycal", @"") action:@selector(terminate:) keyEquivalent:@"q" atIndex:i++];
    NSPoint pt = NSOffsetRect(_btnOpt.frame, -5, -10).origin;
    [optMenu popUpMenuPositioningItem:nil atLocation:pt inView:self.view];
}

- (void)pin:(id)sender
{
    BOOL pin = (_btnPin.state == NSOnState) ? YES : NO;
    [[NSUserDefaults standardUserDefaults] setBool:pin forKey:kPinItsycal];
}

- (void)showWeeks:(id)sender
{
    // The delay gives the menu item time to flicker before
    // setting _moCal.showWeeks which runs an animation.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _moCal.showWeeks = !_moCal.showWeeks;
        [[NSUserDefaults standardUserDefaults] setBool:_moCal.showWeeks forKey:kShowWeeks];
    });
}

- (void)setFirstDayOfWeek:(id)sender
{
    NSMenuItem *item = (NSMenuItem *)sender;
    _moCal.weekStartDOW = [item.menu indexOfItem:item];
    [[NSUserDefaults standardUserDefaults] setInteger:_moCal.weekStartDOW forKey:kWeekStartDOW];
}

- (void)showPrefs:(id)sender
{
    // This statement makes the prefs panel act non-wonky.
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if (!_prefsWC) {
        NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:(NSTitledWindowMask | NSClosableWindowMask) backing:NSBackingStoreBuffered defer:NO];
        _prefsWC = [[NSWindowController alloc] initWithWindow:panel];
        _prefsWC.contentViewController = [PrefsViewController new];
        [panel center];
    }
    // If the window is not visible, we must "close" it before showing it.
    // This seems weird, but is the only way to ensure that -viewWillAppear
    // and -viewDidAppear are called in the prefs VC. When the prefs window
    // is hidden by being deactivated, it appears to have been closed to the
    // user, but it didn't really "close" (it just hid). So we first properly
    // "close" and then our view lifecycle methods are called in the VC.
    // This feels like a hack.
    if (!(_prefsWC.window.occlusionState & NSWindowOcclusionStateVisible)) {
        [_prefsWC close];
    }
    [_prefsWC showWindow:self];
    [_prefsWC.window center];
}

#pragma mark -
#pragma mark Menubar item

- (void)createStatusItem
{
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.button.target = self;
    _statusItem.button.action = @selector(statusItemClicked:);
    _statusItem.highlightMode = NO; // Deprecated in 10.10, but what is alternative?
    [self updateMenubarIcon];
    [self updateStatusItemPositionInfo];
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenFrame:_screenFrame];
    
    // Notification for when status item view moves
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusItemMoved:) name:NSWindowDidMoveNotification object:_statusItem.button.window];
}

- (void)removeStatusItem
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidMoveNotification object:_statusItem.button.window];
    [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
    _statusItem = nil;
}

- (void)menuExtraIsActive:(NSNotification *)notification
{
    [self updateMenuExtraPositionInfoWithUserInfo:notification.userInfo];
    
    [self removeStatusItem];
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalDidUpdateIconNotification object:nil userInfo:@{@"day": @(_moCal.todayDate.day)} deliverImmediately:YES];
}

- (void)menuExtraWillUnload:(NSNotification *)notification
{
    if ([self.itsycalWindow isVisible]) {
        [self.itsycalWindow orderOut:nil];
    }
    [self createStatusItem];
}

- (void)updateMenubarIcon
{
    int day = _moCal.todayDate.day;
    NSImage *datesImage = [NSImage imageNamed:@"dates"];
    NSImage *icon = ItsycalDateIcon(day, datesImage);
    _statusItem.button.image = icon;
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalDidUpdateIconNotification object:nil userInfo:@{@"day": @(_moCal.todayDate.day)} deliverImmediately:YES];
}

- (void)updateStatusItemPositionInfo
{
    _menuItemFrame = [_statusItem.button.window convertRectToScreen:_statusItem.button.frame];
    _screenFrame = [[NSScreen mainScreen] frame];
}

- (void)updateMenuExtraPositionInfoWithUserInfo:(NSDictionary *)userInfo
{
    _menuItemFrame = NSRectFromString(userInfo[@"menuItemFrame"]);
    _screenFrame   = NSRectFromString(userInfo[@"screenFrame"]);
}

- (void)statusItemMoved:(NSNotification *)note
{
    // Reposition itsycalWindow so that it remains
    // centered under _statusItemView.
    //
    // We do the repositioning after a slight delay to account
    // for the following scenario:
    //  - The user has more than one screen.
    //  - Itsycal is visible on one of them.
    //  - The user clicks the menu item on the other screen.
    //
    // In this scenario, this method will be called because the
    // user's click "moved" the status item window from one screen
    // to another. If we repositioned the window immediately, it
    // would be placed on the active screen and the logic in
    // -statusItemClicked: would not be able to know that the click
    // occurred in a different screen from the one where Itsycal
    // was showing. The result would be Itsycal flashing in the
    // new screen (because of this method's repositioning) and then
    // hiding because that's the logic that would execute in the
    // -statusItemClicked: method. The delay let's -menuItemClicked:
    // handle this scenario first.
    [self updateStatusItemPositionInfo];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenFrame:_screenFrame];
    });
}

- (void)menuExtraMoved:(NSNotification *)notification
{
    // see comment in -statusItemMoved:
    [self updateMenuExtraPositionInfoWithUserInfo:notification.userInfo];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenFrame:_screenFrame];
    });
}

- (void)statusItemClicked:(id)sender
{
    [self updateStatusItemPositionInfo];
    [self menuIconClickedAction];
}

- (void)menuExtraClicked:(NSNotification *)notification
{
    [self updateMenuExtraPositionInfoWithUserInfo:notification.userInfo];
    [self menuIconClickedAction];
}

- (void)menuIconClickedAction
{
    // If there are multiple screens and Itsycal is showing
    // on one and the user clicks the menu item on another,
    // instead of a regular toggle, we want Itsycal to hide
    // from it's old screen and show in the new one.
    if (self.itsycalWindow.screen != [NSScreen mainScreen]) {
        if ([self.itsycalWindow occlusionState] & NSWindowOcclusionStateVisible) {
            // The slight delay before showing the window in the new
            // position is to allow -windowDidResignKey: to execute
            // first so that it doesn't hide the window we are
            // trying to show.
            [self.itsycalWindow orderOut:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self showItsycalWindow];
            });
            return;
        }
    }
    [self toggleItsycalWindow];
}

#pragma mark -
#pragma mark Window management

- (ItsycalWindow *)itsycalWindow
{
    return (ItsycalWindow *)self.view.window;
}

- (void)toggleItsycalWindow
{
    if ([self.itsycalWindow occlusionState] & NSWindowOcclusionStateVisible) {
        [self.itsycalWindow orderOut:self];
    }
    else {
        [self showItsycalWindow];
    }
}

- (void)showItsycalWindow
{
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenFrame:_screenFrame];
    [self.itsycalWindow makeKeyAndOrderFront:self];
    [self.itsycalWindow makeFirstResponder:_moCal];
}

- (void)cancel:(id)sender
{
    // User pressed 'esc'.
    [self.itsycalWindow orderOut:self];
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenFrame:_screenFrame];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    if (_btnPin.state == NSOffState) {
        [self.itsycalWindow orderOut:self];
    }
}

- (void)keyboardShortcutActivated
{
    // The user hit the keyboard shortcut. This is the same
    // as if the user had clicked the menubar icon. If the
    // icon is the statusItem it is straightforward: just
    // simulate a click on the statusItem. If the icon is the
    // menuextra, we need to send it a message so it can
    // simulate the click.
    if (_statusItem) {
        [self statusItemClicked:self];
    }
    else {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalKeyboardShortcutNotification object:nil userInfo:nil deliverImmediately:YES];
    }
}

#pragma mark -
#pragma mark Time

- (MoDate)todayDate
{
    NSDateComponents *c = [_nsCal components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate new]];
    return MakeDate((int)c.year, (int)c.month-1, (int)c.day);
}

- (void)dayChanged:(NSNotification *)note
{
    MoDate today = self.todayDate;
    [_moCal setTodayDate:today];
    [_moCal setSelectedDate:today];
    [self updateMenubarIcon];
}

@end
