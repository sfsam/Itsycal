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

@implementation ViewController
{
    MoCalendar    *_moCal;
    NSCalendar    *_nsCal;
    NSStatusItem  *_statusItem;
    NSButton      *_btnAdd, *_btnCal, *_btnOpt;
    NSRect         _menuItemFrame, _screenFrame;
    BOOL           _pin;
    
    NSWindowController *_prefsWC;
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
    NSButton* (^btn)(NSString*, NSString*, NSString*, SEL) = ^NSButton* (NSString *imageName, NSString *tip, NSString *key, SEL action) {
        NSButton *btn = [NSButton new];
        [btn setButtonType:NSMomentaryChangeButton];
        [btn setBordered:NO];
        [btn setTarget:self];
        [btn setAction:action];
        [btn setToolTip:NSLocalizedString(tip, @"")];
        [btn setImage:[NSImage imageNamed:imageName]];
        [btn setImagePosition:NSImageOnly];
        [btn setKeyEquivalent:key];
        [btn setKeyEquivalentModifierMask:NSCommandKeyMask];
        [btn setTranslatesAutoresizingMaskIntoConstraints:NO];
        [v addSubview:btn];
        return btn;
    };

    // Add, Calendar.app and Options buttons
    _btnAdd = btn(@"btnAdd", @"New Event... ⌘N", @"n", @selector(addCalendarEvent:));
    _btnCal = btn(@"btnCal", @"Open Calendar... ⌘O", @"o", @selector(showCalendarApp:));
    _btnOpt = btn(@"btnOpt", @"Options", @"", @selector(showOptionsMenu:));
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*, NSLayoutFormatOptions) = ^(NSString *format, NSLayoutFormatOptions opts) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:opts metrics:nil views:NSDictionaryOfVariableBindings(_moCal, _btnAdd, _btnCal, _btnOpt)]];
    };
    vcon(@"H:|[_moCal]|", 0);
    vcon(@"V:|[_moCal]-(28)-|", 0);
    vcon(@"V:[_moCal]-(10)-[_btnOpt]", 0);
    vcon(@"H:|-(8)-[_btnAdd]-(>=0)-[_btnCal]-(12)-[_btnOpt]-(8)-|", NSLayoutFormatAlignAllCenterY);
    
    self.view = v;
}

- (void)viewDidLoad
{
//    NSLog(@"%s", __FUNCTION__);
    [super viewDidLoad];
    
    // The order of the statements is important!

    _nsCal = [NSCalendar autoupdatingCurrentCalendar];
    
    MoDate today = self.todayDate;
    [_moCal setTodayDate:today];
    [_moCal setSelectedDate:today];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dayChanged:) name:NSCalendarDayChangedNotification object:nil];

    [self createStatusItem];
}

- (void)viewWillAppear
{
//    NSLog(@"%s", __FUNCTION__);
    [super viewWillAppear];
    [self.itsycalWindow makeFirstResponder:_moCal];
}

- (void)viewDidAppear
{
//    NSLog(@"%s", __FUNCTION__);
    [super viewDidAppear];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _pin = [defaults boolForKey:kPinItsycal];
    _moCal.showWeeks = [defaults boolForKey:kShowWeeks];
    _moCal.weekStartDOW = [defaults integerForKey:kWeekStartDOW];
    
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenMaxX:NSMaxX(_screenFrame)];
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
    
    if (keyChar == 'p' && noFlags) {
        [self pin:self];
    }
    else if (keyChar == 'w' && noFlags) {
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
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"Pin Itsycal", @"") action:@selector(pin:) keyEquivalent:@"p" atIndex:i++];
    item.state = _pin ? NSOnState : NSOffState;
    item.keyEquivalentModifierMask = 0;
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"Show calendar weeks", @"") action:@selector(showWeeks:) keyEquivalent:@"w" atIndex:i++];
    item.state = _moCal.showWeeks ? NSOnState : NSOffState;
    item.keyEquivalentModifierMask = 0;
    
    // Week Start submenu
    NSMenu *weekStartMenu = [[NSMenu alloc] initWithTitle:@"Week Start Menu"];
    NSInteger i2 = 0;
    [weekStartMenu insertItemWithTitle:NSLocalizedString(@"Sunday", @"") action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    [weekStartMenu insertItemWithTitle:NSLocalizedString(@"Monday", @"") action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    [weekStartMenu insertItemWithTitle:NSLocalizedString(@"Tuesday", @"") action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    [weekStartMenu insertItemWithTitle:NSLocalizedString(@"Wednesday", @"") action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    [weekStartMenu insertItemWithTitle:NSLocalizedString(@"Thursday", @"") action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    [weekStartMenu insertItemWithTitle:NSLocalizedString(@"Friday", @"") action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    [weekStartMenu insertItemWithTitle:NSLocalizedString(@"Saturday", @"") action:@selector(setFirstDayOfWeek:) keyEquivalent:@"" atIndex:i2++];
    [[weekStartMenu itemAtIndex:_moCal.weekStartDOW] setState:NSOnState];
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"First day of week", @"") action:NULL keyEquivalent:@"" atIndex:i++];
    item.submenu = weekStartMenu;
    
    [optMenu insertItem:[NSMenuItem separatorItem] atIndex:i++];
    [optMenu insertItemWithTitle:NSLocalizedString(@"Preferences...", @"") action:@selector(showPrefs:) keyEquivalent:@"," atIndex:i++];
    [optMenu insertItem:[NSMenuItem separatorItem] atIndex:i++];
    [optMenu insertItemWithTitle:NSLocalizedString(@"Quit", @"") action:@selector(terminate:) keyEquivalent:@"q" atIndex:i++];
    NSPoint pt = NSOffsetRect(_btnOpt.frame, -5, -10).origin;
    [optMenu popUpMenuPositioningItem:nil atLocation:pt inView:self.view];
}

- (void)pin:(id)sender
{
    _pin = !_pin;
    [[NSUserDefaults standardUserDefaults] setBool:_pin forKey:kPinItsycal];
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
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:(NSTitledWindowMask | NSClosableWindowMask) backing:NSBackingStoreBuffered defer:NO];
        window.hidesOnDeactivate = YES;
        _prefsWC = [[NSWindowController alloc] initWithWindow:window];
        _prefsWC.contentViewController = [PrefsViewController new];
        [window center];
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
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenMaxX:NSMaxX(_screenFrame)];
    
    // Notification for when status item view moves
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusItemMoved:) name:NSWindowDidMoveNotification object:_statusItem.button.window];
}

- (void)removeStatusItem
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidMoveNotification object:_statusItem.button.window];
    [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
    _statusItem = nil;
}

- (void)updateStatusItemPositionInfo
{
    _menuItemFrame = [_statusItem.button.window convertRectToScreen:_statusItem.button.frame];
    _screenFrame = [[NSScreen mainScreen] frame];
}

- (void)statusItemMoved:(NSNotification *)note
{
    [self updateStatusItemPositionInfo];
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenMaxX:NSMaxX(_screenFrame)];
}

- (void)statusItemClicked:(id)sender
{
    [self toggleItsycalWindow];
}

- (void)updateMenubarIcon
{
    int day = _moCal.todayDate.day;
    NSImage *datesImage = [NSImage imageNamed:@"dates"];
    NSImage *icon = ItsycalDateIcon(day, datesImage);
    _statusItem.button.image = icon;
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
        [self hideItsycalWindow];
    }
    else {
        [self showItsycalWindow];
    }
}

- (void)showItsycalWindow
{
    [self.itsycalWindow makeKeyAndOrderFront:self];
}

- (void)hideItsycalWindow
{
    [self.itsycalWindow orderOut:self];
}

- (void)cancel:(id)sender
{
    // User pressed 'esc'.
    [self hideItsycalWindow];
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenMaxX:NSMaxX(_screenFrame)];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    if (!_pin) {
        [self hideItsycalWindow];
    }
}

- (void)keyboardShortcutActivated
{
    [self toggleItsycalWindow];
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
