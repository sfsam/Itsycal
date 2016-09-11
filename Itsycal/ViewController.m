//
//  ViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "ViewController.h"
#import "Itsycal.h"
#import "ItsycalWindow.h"
#import "SBCalendar.h"
#import "EventViewController.h"
#import "PrefsViewController.h"
#import "TooltipViewController.h"
#import "MoButton.h"
#import "Sparkle/SUUpdater.h"

@implementation ViewController
{
    EventCenter   *_ec;
    MoCalendar    *_moCal;
    NSCalendar    *_nsCal;
    NSStatusItem  *_statusItem;
    MoButton      *_btnAdd, *_btnCal, *_btnOpt, *_btnPin;
    NSRect         _menuItemFrame, _screenFrame;
    NSWindowController    *_prefsWC;
    AgendaViewController  *_agendaVC;
    EventViewController   *_eventVC;
    NSLayoutConstraint    *_bottomMargin;
    NSDateFormatter       *_iconDateFormatter;
    NSTimer               *_clockTimer;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowEventDays];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowIcon];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowData];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowDayOfWeek];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowTime];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kUse24Hour];
    [_clockTimer invalidate];
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
    _moCal.delegate = self;
    _moCal.target = self;
    _moCal.doubleAction = @selector(addCalendarEvent:);
    [v addSubview:_moCal];
    
    // Convenience function to config buttons.
    MoButton* (^btn)(NSString*, NSString*, NSString*, SEL) = ^MoButton* (NSString *imageName, NSString *tip, NSString *key, SEL action) {
        MoButton *btn = [MoButton new];
        [btn setButtonType:NSMomentaryChangeButton];
        [btn setTarget:self];
        [btn setAction:action];
        [btn setToolTip:tip];
        [btn setImage:[NSImage imageNamed:imageName]];
        [btn setKeyEquivalent:key];
        [btn setKeyEquivalentModifierMask:NSCommandKeyMask];
        [v addSubview:btn];
        return btn;
    };

    // Add event, Calendar.app, and Options buttons
    _btnAdd = btn(@"btnAdd", NSLocalizedString(@"New Event... ⌘N", @""), @"n", @selector(addCalendarEvent:));
    _btnCal = btn(@"btnCal", NSLocalizedString(@"Open Calendar... ⌘O", @""), @"o", @selector(showCalendarApp:));
    _btnOpt = btn(@"btnOpt", NSLocalizedString(@"Options", @""), @"", @selector(showOptionsMenu:));
    _btnPin = btn(@"btnPin", NSLocalizedString(@"Pin Itsycal... P", @""), @"p", @selector(pin:));
    _btnPin.keyEquivalentModifierMask = 0;
    _btnPin.alternateImage = [NSImage imageNamed:@"btnPinAlt"];
    [_btnPin setButtonType:NSToggleButton];
    
    // Agenda
    _agendaVC = [AgendaViewController new];
    _agendaVC.delegate = self;
    NSView *agenda = _agendaVC.view;
    [v addSubview:agenda];
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*, NSLayoutFormatOptions) = ^(NSString *format, NSLayoutFormatOptions opts) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:opts metrics:nil views:NSDictionaryOfVariableBindings(_moCal, _btnAdd, _btnCal, _btnOpt, _btnPin, agenda)]];
    };
    vcon(@"H:|[_moCal]|", 0);
    vcon(@"H:|[agenda]|", 0);
    vcon(@"H:|-6-[_btnAdd]-(>=0)-[_btnPin]-10-[_btnCal]-10-[_btnOpt]-6-|", NSLayoutFormatAlignAllCenterY);
    vcon(@"V:|[_moCal]-6-[_btnOpt]", 0);
    vcon(@"V:[agenda]-(-2)-|", 0);
    
    // Margin between bottom of _moCal and top of agenda. When the agenda
    // has no items, we reduce this space so that the bottom of the window
    // is a bit closer to the buttons. This eliminates the chin.
    _bottomMargin = [NSLayoutConstraint constraintWithItem:agenda attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_moCal attribute:NSLayoutAttributeBottom multiplier:1 constant:30];
    [v addConstraint:_bottomMargin];
    
    self.view = v;
}

- (void)viewDidLoad
{
    // The order of the statements is important! Subsequent statments
    // depend on previous ones.
    
    _iconDateFormatter = [NSDateFormatter new];

    // Calendar is 'autoupdating' so it handles timezone changes properly.
    _nsCal = [NSCalendar autoupdatingCurrentCalendar];
    _agendaVC.nsCal = _nsCal;
    
    MoDate today = [self todayDate];
    _moCal.todayDate = today;
    _moCal.selectedDate = today;
    
    [self createStatusItem];
    
    _ec = [[EventCenter alloc] initWithCalendar:_nsCal delegate:self];
    
    TooltipViewController *tooltipVC = [TooltipViewController new];
    tooltipVC.ec = _ec;
    _moCal.tooltipVC = tooltipVC;

    // Now that everything else is set up, we file for notifications.
    // Some of the notification handlers rely on stuff we just set up.
    [self fileNotifications];
    
    // Tell the menu extra that Itsycal is alive
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalIsActiveNotification object:nil userInfo:@{@"dateText": [self getDateText], @"iconText": [self getIconText]} deliverImmediately:YES];
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _btnPin.state = [defaults boolForKey:kPinItsycal] ? NSOnState : NSOffState;
    _moCal.showWeeks = [defaults boolForKey:kShowWeeks];
    _moCal.highlightWeekend = [defaults boolForKey:kHighlightWeekend];
    _moCal.weekStartDOW = [defaults integerForKey:kWeekStartDOW];
    
    [self.itsycalWindow makeFirstResponder:_moCal];
}

- (void)viewDidAppear
{
    [super viewDidAppear];

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
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if (_ec.calendarAccessGranted == NO) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Calendar access was denied.", @"");
        alert.informativeText = NSLocalizedString(@"Itsycal is more useful when you allow it to add events to your calendars. You can change this setting in System Preferences › Security & Privacy › Privacy.", @"");
        [alert runModal];
        return;
    }

    if (!_eventVC) {
        _eventVC = [EventViewController new];
        _eventVC.ec = _ec;
        _eventVC.cal = _nsCal;
        _eventVC.title = @"";
    }
    _eventVC.calSelectedDate = MakeNSDateWithDate(_moCal.selectedDate, _nsCal);
    [self presentViewControllerAsModalWindow:_eventVC];
}

- (void)showCalendarApp:(id)sender
{
    // Determine the default calendar app.
    // See: support.busymac.com/help/21535-busycal-url-handler
    
    CFStringRef strRef = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, CFSTR("ics"), kUTTypeData);
    CFStringRef bundleID = LSCopyDefaultRoleHandlerForContentType(strRef, kLSRolesEditor);
    CFRelease(strRef);
    NSString *defaultCalendarAppBundleID = CFBridgingRelease(bundleID);
    
    // Use URL scheme to open BusyCal or Fantastical2 on the
    // date selected in our calendar.
    
    if ([defaultCalendarAppBundleID isEqualToString:@"com.busymac.busycal2"]) {
        [self showCalendarAppWithURLScheme:@"busycalevent://date"];
        return;
    }
    else if ([defaultCalendarAppBundleID isEqualToString:@"com.flexibits.fantastical2.mac"]) {
        [self showCalendarAppWithURLScheme:@"x-fantastical2://show/calendar"];
        return;
    }
    
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
    [calendarApp activate]; // bring to foreground
    [calendarApp viewCalendarAt:MakeNSDateWithDate(_moCal.selectedDate, _nsCal)];
}

- (void)showCalendarAppWithURLScheme:(NSString *)urlScheme
{
    // url is of the form: urlScheme/yyyy-MM-dd
    // For example: x-fantastical2://show/calendar/2011-05-22
    NSString *url = [NSString stringWithFormat:@"%@/%04zd-%02zd-%02zd", urlScheme, _moCal.selectedDate.year, _moCal.selectedDate.month+1, _moCal.selectedDate.day];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (void)showOptionsMenu:(id)sender
{
    NSMenu *optMenu = [[NSMenu alloc] initWithTitle:@"Options Menu"];
    NSInteger i = 0;
    NSMenuItem *item;
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"Show calendar weeks", @"") action:@selector(showWeeks:) keyEquivalent:@"w" atIndex:i++];
    item.state = _moCal.showWeeks ? NSOnState : NSOffState;
    item.keyEquivalentModifierMask = 0;

    item = [optMenu insertItemWithTitle:NSLocalizedString(@"Highlight weekend", @"") action:@selector(highlightWeekend:) keyEquivalent:@"" atIndex:i++];
    item.state = _moCal.highlightWeekend ? NSOnState : NSOffState;

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
    [optMenu insertItemWithTitle:NSLocalizedString(@"Check for updates...", @"") action:@selector(checkForUpdates:) keyEquivalent:@"" atIndex:i++];
    [optMenu insertItem:[NSMenuItem separatorItem] atIndex:i++];
    [optMenu insertItemWithTitle:NSLocalizedString(@"Quit Itsycal", @"") action:@selector(terminate:) keyEquivalent:@"q" atIndex:i++];
    NSPoint pt = NSOffsetRect(_btnOpt.frame, -5, -10).origin;
    [optMenu popUpMenuPositioningItem:nil atLocation:pt inView:self.view];
}

- (void)pin:(id)sender
{
    BOOL pin = _btnPin.state == NSOnState;
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

- (void)highlightWeekend:(id)sender
{
    _moCal.highlightWeekend = !_moCal.highlightWeekend;
    [[NSUserDefaults standardUserDefaults] setBool:_moCal.highlightWeekend forKey:kHighlightWeekend];
}

- (void)setFirstDayOfWeek:(id)sender
{
    NSMenuItem *item = (NSMenuItem *)sender;
    _moCal.weekStartDOW = [item.menu indexOfItem:item];
    [[NSUserDefaults standardUserDefaults] setInteger:_moCal.weekStartDOW forKey:kWeekStartDOW];
}

- (void)showPrefs:(id)sender
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if (!_prefsWC) {
        NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:(NSTitledWindowMask | NSClosableWindowMask) backing:NSBackingStoreBuffered defer:NO];
        PrefsViewController *prefsVC = [PrefsViewController new];
        prefsVC.ec = _ec;
        _prefsWC = [[NSWindowController alloc] initWithWindow:panel];
        _prefsWC.contentViewController = prefsVC;
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

- (void)checkForUpdates:(id)sender
{
    [[SUUpdater sharedUpdater] checkForUpdates:self];
}

#pragma mark -
#pragma mark Menubar item

- (void)createStatusItem
{
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
//    _statusItem.button.target = self;
//    _statusItem.button.action = @selector(statusItemClicked:);
//    _statusItem.highlightMode = NO; // Deprecated in 10.10, but what is alternative?
    
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSLeftMouseDown | NSRightMouseDown)
                                          handler:^NSEvent *(NSEvent *event) {
                                              if (event.window == _statusItem.button.window) {
                                                  [self statusItemClicked:nil];
                                                  return nil;
                                              }
                                              return event;
                                          }];
    
    // fix title y position
    NSRect frame = _statusItem.button.frame;
    frame.size.height += 1;
    _statusItem.button.frame = frame;
    
    [self updateMenubarIcon];
    [self updateStatusItemPositionInfo];
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenFrame:_screenFrame];
    
    // Notification for when status item view moves
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusItemMoved:) name:NSWindowDidMoveNotification object:_statusItem.button.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusItemMoved:) name:NSWindowDidResizeNotification object:_statusItem.button.window];
}

- (void)removeStatusItem
{
    if (_statusItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidMoveNotification object:_statusItem.button.window];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:_statusItem.button.window];
        [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
        _statusItem = nil;
    }
}

- (void)menuExtraIsActive:(NSNotification *)notification
{
    [self updateMenuExtraPositionInfoWithUserInfo:notification.userInfo];
    [self removeStatusItem];
    [self updateMenubarIcon];
}

- (void)menuExtraWillUnload:(NSNotification *)notification
{
    if ([self.itsycalWindow isVisible]) {
        [self.itsycalWindow orderOut:nil];
    }
    [self createStatusItem];
}

- (NSString*)getIconText
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowIcon])
        return [NSString stringWithFormat:@"%zd", _moCal.todayDate.day];
    else
        return @"";
}

- (NSString *)getDateText
{
    NSMutableString *template = [[NSMutableString alloc] init];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowData]) {
        [template appendString:@"dMMM"];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowDayOfWeek]) {
        [template appendString:@"EEE"];
    }
    
    NSMutableString* dateFormat = [NSDateFormatter dateFormatFromTemplate:template options:0 locale:[NSLocale currentLocale]].mutableCopy;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowTime]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kUse24Hour]) {
            template = @"H:mm".mutableCopy;
        }
        else {
            template = @"h:mm a".mutableCopy;
        }
        
        if (dateFormat.length)
            [dateFormat appendString:@" "];
        
        [dateFormat appendString:[NSDateFormatter dateFormatFromTemplate:template options:0 locale:[NSLocale currentLocale]]];
    }
    
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:dateFormat];
    
    NSDate *date = [NSDate date];
    NSMutableString *dateText = [[NSMutableString alloc] init];
    [dateText appendString:[dateFormatter stringFromDate:date]];

    return dateText;
}

- (void)updateMenubarIcon
{
    NSString *dateText = [self getDateText];
    NSString *iconText = [self getIconText];
    NSImage *iconImage = nil;
    if (iconText.length)
        iconImage = ItsycalIconImageForText(iconText);
    
    if (_statusItem) {
        _statusItem.button.image = iconImage;
        _statusItem.title = dateText;
    }
    
    // If not load ItsycalExtra, fix status width
    if (OSVersionIsAtLeast(10, 11, 0)) {
        CGRect textRect = [dateText boundingRectWithSize:CGSizeMake(MAXFLOAT, MAXFLOAT)
                                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                                attributes:@{NSFontAttributeName:_statusItem.button.font}
                                                                   context:nil];
        
        // Add blank
        if (textRect.size.width)
            textRect.size.width += 6;
        
        // Adjust size of menu extra based on iconImage size
        NSRect frame = _statusItem.view.frame;
        frame.size.width = iconImage.size.width + textRect.size.width;
        _statusItem.view.frame = frame;
        _statusItem.length = iconImage.size.width + textRect.size.width;
    }
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalDidUpdateIconNotification object:nil userInfo:@{@"dateText": dateText, @"iconText": iconText} deliverImmediately:YES];
}

- (void)updateStatusItemPositionInfo
{
    _menuItemFrame = [_statusItem.button.window convertRectToScreen:_statusItem.button.frame];
    _screenFrame = [[NSScreen mainScreen] frame];
    
    // Constrain the menu item's frame to be no higher than the top
    // of the screen. For some reason, when an app is in fullscreen
    // mode sometimes the menu item frame is reported to be *above*
    // the top of the screen. The result is that the calendar is
    // shown clipped at the top. Prevent that by constraining the
    // top of the menu item to be at most the top of the screen.
    _menuItemFrame.origin.y = MIN(_menuItemFrame.origin.y, _screenFrame.origin.y + _screenFrame.size.height);
}

- (void)updateMenuExtraPositionInfoWithUserInfo:(NSDictionary *)userInfo
{
    _menuItemFrame = NSRectFromString(userInfo[@"menuItemFrame"]);
    _screenFrame   = NSRectFromString(userInfo[@"screenFrame"]);
    // See comment above in -updateStatusItemPositionInfo.
    _menuItemFrame.origin.y = MIN(_menuItemFrame.origin.y, _screenFrame.origin.y + _screenFrame.size.height);
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
    _statusItem.button.highlighted = YES;
    [[NSApplication sharedApplication] unhideWithoutActivation];
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
        _statusItem.button.highlighted = NO;
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
#pragma mark AgendaDelegate

- (void)agendaHoveredOverRow:(NSInteger)row
{
    if (row == -1) {
        [_moCal unhighlightCells];
    }
    else {
        EventInfo *info = _agendaVC.events[row];
        MoDate startDate = MakeDateWithNSDate(info.event.startDate, _nsCal);
        MoDate endDate   = MakeDateWithNSDate(info.event.endDate,   _nsCal);
        // Fixup for endDates that are at midnight
        if ([info.event.endDate compare:[_nsCal startOfDayForDate:info.event.endDate]] == NSOrderedSame) {
            endDate = AddDaysToDate(-1, endDate);
        }
        [_moCal highlightCellsFromDate:startDate toDate:endDate withColor:info.event.calendar.color];
    }
}

- (void)agendaWantsToDeleteEvent:(EKEvent *)event
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

    BOOL eventRepeats = event.hasRecurrenceRules;
    
    // Ask the user to confirm they want to delete this event (or future events).
    NSAlert *alert = [NSAlert new];
    if (eventRepeats == YES) {
        alert.messageText = NSLocalizedString(@"You're deleting an event.", @"");
        alert.informativeText = NSLocalizedString(@"Do you want to delete this and all future occurrences of this event, or only the selected occurrence?", @"");
        [alert addButtonWithTitle:NSLocalizedString(@"Delete Only This Event", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Delete All Future Events", @"")];
    }
    else {
        alert.messageText = NSLocalizedString(@"Are you sure you want to delete this event?", @"");
        [alert addButtonWithTitle:NSLocalizedString(@"Delete This Event", @"")];
    }
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
    NSModalResponse response = [alert runModal];
    
    // Return if the user chose 'Cancel'.
    if ((eventRepeats == YES && response == NSAlertThirdButtonReturn) ||
        (eventRepeats == NO && response == NSAlertSecondButtonReturn)) {
        return;
    }
    
    // Delete this event (or future events).
    NSError *error = NULL;
    EKSpan span = (eventRepeats && response == NSAlertSecondButtonReturn) ? EKSpanFutureEvents : EKSpanThisEvent;
    BOOL result = [_ec.store removeEvent:event span:span commit:YES error:&error];
    if (result == NO && error != nil) {
        [[NSAlert alertWithError:error] runModal];
    }
}

#pragma mark -
#pragma mark MoCalendarDelegate

- (void)calendarUpdated:(MoCalendar *)cal
{
    // Attempt to reload cached events. If this works,
    // the display will update fast. Then fetch.
    [_moCal reloadData];
    [_ec fetchEvents];
}

- (void)calendarSelectionChanged:(MoCalendar *)cal
{
    [self updateAgenda];
}

- (BOOL)dateHasDot:(MoDate)date
{
    return [_ec eventsForDate:date] != nil;
}

#pragma mark -
#pragma mark EventCenterDelegate

- (void)eventCenterEventsChanged
{
    [_moCal reloadData];
    [self updateAgenda];
}

- (MoDate)fetchStartDate
{
    return AddDaysToDate(-40, _moCal.monthDate);
}

- (MoDate)fetchEndDate
{
    return AddDaysToDate(80, _moCal.monthDate);
}

#pragma mark -
#pragma mark Agenda

- (void)updateAgenda
{
    NSInteger days = [[NSUserDefaults standardUserDefaults] integerForKey:kShowEventDays];
    days = MIN(MAX(days, 0), 7); // days is in range 0..7
    _agendaVC.events = [_ec datesAndEventsForDate:_moCal.selectedDate days:days];
    [_agendaVC reloadData];
    _bottomMargin.constant = _agendaVC.events.count == 0 ? 26 : 30;
}

#pragma mark -
#pragma mark Time

- (MoDate)todayDate
{
    NSDateComponents *c = [_nsCal components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate new]];
    return MakeDate(c.year, c.month-1, c.day);
}

- (void)clockTick:(NSTimer *)timer
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowTime]) {
        [self updateMenubarIcon];
    }
}

#pragma mark -
#pragma mark Notifications

- (void)fileNotifications
{
    // Menu extra notifications
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraIsActive:) name:ItsycalExtraIsActiveNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraClicked:) name:ItsycalExtraClickedNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraMoved:) name:ItsycalExtraDidMoveNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraWillUnload:) name:ItsycalExtraWillUnloadNotification object:nil];
    
    // Day changed notification
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        MoDate today = [self todayDate];
        _moCal.todayDate = today;
        _moCal.selectedDate = today;
        [self updateMenubarIcon];
    }];
    
    // Time changed timer
    // create a timer object
    _clockTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(clockTick:)
                                                userInfo:nil
                                                 repeats:YES];
    [_clockTimer fire];
    
    // Timezone changed notification
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemTimeZoneDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [_ec refetchAll];
    }];
    
    // Locale notifications
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self updateMenubarIcon];
    }];
    
    // Observe NSUserDefaults for preference changes
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kShowEventDays options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kShowIcon options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kShowData options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kShowDayOfWeek options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kShowTime options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kUse24Hour options:NSKeyValueObservingOptionNew context:NULL];
}

#pragma mark -
#pragma mark NSUserDefaults observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:kShowEventDays]) {
        [self updateAgenda];
    }
    else if ([keyPath isEqualToString:kShowIcon] || [keyPath isEqualToString:kShowData] || [keyPath isEqualToString:kShowDayOfWeek] || [keyPath isEqualToString:kShowTime] || [keyPath isEqualToString:kUse24Hour]) {
        [self updateMenubarIcon];
    }
}

@end
