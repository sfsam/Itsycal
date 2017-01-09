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

    NSString  *_clockFormat;
    NSTimer   *_clockTimer;
    BOOL       _clockUsesSeconds;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowEventDays];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kUseOutlineIcon];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowMonthInIcon];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kShowDayOfWeekInIcon];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kClockFormat];
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
        [btn setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
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
    BOOL noFlags = !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl));
    BOOL cmdFlag = (flags & NSEventModifierFlagCommand) &&  !(flags & (NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl));
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
        alert.alertStyle = NSAlertStyleCritical;
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
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"Show Calendar Weeks", @"") action:@selector(showWeeks:) keyEquivalent:@"w" atIndex:i++];
    item.state = _moCal.showWeeks ? NSOnState : NSOffState;
    item.keyEquivalentModifierMask = 0;

    item = [optMenu insertItemWithTitle:NSLocalizedString(@"Highlight Weekend", @"") action:@selector(highlightWeekend:) keyEquivalent:@"" atIndex:i++];
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
    item = [optMenu insertItemWithTitle:NSLocalizedString(@"First Day of Week", @"") action:NULL keyEquivalent:@"" atIndex:i++];
    item.submenu = weekStartMenu;
    
    [optMenu insertItem:[NSMenuItem separatorItem] atIndex:i++];
    [optMenu insertItemWithTitle:NSLocalizedString(@"Preferences...", @"") action:@selector(showPrefs:) keyEquivalent:@"," atIndex:i++];
    [optMenu insertItem:[NSMenuItem separatorItem] atIndex:i++];
    [optMenu insertItemWithTitle:NSLocalizedString(@"Check for Updates...", @"") action:@selector(checkForUpdates:) keyEquivalent:@"" atIndex:i++];
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
        NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable) backing:NSBackingStoreBuffered defer:NO];
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
    _statusItem.button.target = self;
    _statusItem.button.action = @selector(statusItemClicked:);
    _statusItem.highlightMode = NO; // Deprecated in 10.10, but what is alternative?

    // Use monospaced font in case user sets custom clock format.
    // We modify the default font with a font descriptor instead
    // of using +monospacedDigitSystemFontOfSize:weight: because
    // we get slightly darker looking ':' characters this way.
    NSFontDescriptor *fontDesc = [_statusItem.button.font fontDescriptor];
    fontDesc = [fontDesc fontDescriptorByAddingAttributes:@{NSFontFeatureSettingsAttribute: @[@{NSFontFeatureTypeIdentifierKey: @(kNumberSpacingType), NSFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}]}];
    _statusItem.button.font = [NSFont fontWithDescriptor:fontDesc size:0];

    // Remember item position in menubar. (@pskowronek (Github))
    [_statusItem setAutosaveName:@"ItsycalStatusItem"];

    [self clockFormatDidChange];
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
        // Let 10.12+ remember item position and remove item when app is terminated.
        // If we remove item ourselves, autosavename is deleted from user defaults.
        // (@pskowronek (Github))
        // DO NOT do this:
        //   [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
        //   _statusItem = nil;
    }
}

- (NSString *)iconText
{
    NSString *iconText;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowMonthInIcon] || [[NSUserDefaults standardUserDefaults] boolForKey:kShowDayOfWeekInIcon]) {
        NSMutableString *template = @"d".mutableCopy;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowMonthInIcon]) {
            [template appendString:@"MMM"];
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kShowDayOfWeekInIcon]) {
            [template appendString:@"EEE"];
        }
        [_iconDateFormatter setDateFormat:[NSDateFormatter dateFormatFromTemplate:template options:0 locale:[NSLocale currentLocale]]];
        iconText = [_iconDateFormatter stringFromDate:[NSDate new]];
    } else {
        iconText = [NSString stringWithFormat:@"%zd", _moCal.todayDate.day];
    }
    
    if (iconText == nil) {
        iconText = @"!!";
    }
    return iconText;
}

- (void)updateMenubarIcon
{
    NSString *iconText = [self iconText];
    _statusItem.button.image = [self iconImageForText:iconText];

    if (_clockFormat) {
        [_iconDateFormatter setDateFormat:_clockFormat];
        _statusItem.button.title = [_iconDateFormatter stringFromDate:[NSDate new]];
        [self updateClock];
    }
}

- (NSImage *)iconImageForText:(NSString *)text
{
    if (text == nil) text = @"!";

    // Does user want outline icon or solid icon?
    BOOL useOutlineIcon = [[NSUserDefaults standardUserDefaults] boolForKey:kUseOutlineIcon];

    // Return cached icon if one is available.
    NSString *iconName = [text stringByAppendingString:useOutlineIcon ? @" outline" : @" solid"];
    NSImage *iconImage = [NSImage imageNamed:iconName];
    if (iconImage != nil) {
        return iconImage;
    }

    // Measure text width
    NSFont *font = [NSFont monospacedDigitSystemFontOfSize:11.5 weight:NSFontWeightBold];
    CGRect textRect = [[[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: font}] boundingRectWithSize:CGSizeMake(999, 999) options:0 context:nil];

    // Icon width is at least 19 pts with 3 pt outside margins, 4 pt inside margins.
    CGFloat width = MAX(3 + 4 + ceilf(NSWidth(textRect)) + 4 + 3, 19);
    CGFloat height = 16;
    iconImage = [NSImage imageWithSize:NSMakeSize(width, height) flipped:NO drawingHandler:^BOOL (NSRect rect) {

        // Get image's context.
        CGContextRef const ctx = [[NSGraphicsContext currentContext] graphicsPort];

        if (useOutlineIcon) {

            // Draw outlined icon image.

            [[NSColor colorWithWhite:0 alpha:0.9] set];
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 3.5, 0.5) xRadius:2 yRadius:2] stroke];

            [[NSColor colorWithWhite:0 alpha:0.15] set];
            NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 4, 1) xRadius:1 yRadius:1];
            [p setLineWidth:2];
            [p stroke];

            // Turning off smoothing looks better (why??).
            CGContextSetShouldSmoothFonts(ctx, false);

            // Draw text.
            NSMutableParagraphStyle *pstyle = [NSMutableParagraphStyle new];
            pstyle.alignment = NSTextAlignmentCenter;
            [text drawInRect:NSOffsetRect(rect, 0, -1) withAttributes:@{NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11.5 weight:NSFontWeightSemibold], NSParagraphStyleAttributeName: pstyle, NSForegroundColorAttributeName: [NSColor blackColor]}];
        }
        else {

            // Draw solid background icon image.
            // Based on cocoawithlove.com/2009/09/creating-alpha-masks-from-text-on.html

            // Make scale adjustments.
            NSRect deviceRect = CGContextConvertRectToDeviceSpace(ctx, rect);
            CGFloat scale  = NSHeight(deviceRect)/NSHeight(rect);
            CGFloat width  = scale * NSWidth(rect);
            CGFloat height = scale * NSHeight(rect);
            CGFloat outsideMargin = scale * 3;
            CGFloat radius = scale * 2;
            CGFloat fontSize = scale > 1 ? 24 : 11.5;

            // Create a grayscale context for the mask
            CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
            CGContextRef maskContext = CGBitmapContextCreate(NULL, width, height, 8, 0, colorspace, 0);
            CGColorSpaceRelease(colorspace);

            // Switch to the context for drawing.
            // Drawing done in this context is scaled.
            NSGraphicsContext *maskGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:maskContext flipped:NO];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:maskGraphicsContext];

            // Draw a white rounded rect background into the mask context
            [[NSColor whiteColor] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(deviceRect, outsideMargin, 0) xRadius:radius yRadius:radius] fill];

            // Draw text.
            NSMutableParagraphStyle *pstyle = [NSMutableParagraphStyle new];
            pstyle.alignment = NSTextAlignmentCenter;
            [text drawInRect:NSOffsetRect(deviceRect, 0, -1) withAttributes:@{NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:fontSize weight:NSFontWeightBold], NSForegroundColorAttributeName: [NSColor blackColor], NSParagraphStyleAttributeName: pstyle}];

            // Switch back to the image's context.
            [NSGraphicsContext restoreGraphicsState];

            // Create an image mask from our mask context.
            CGImageRef alphaMask = CGBitmapContextCreateImage(maskContext);

            // Fill the image, clipped by the mask.
            CGContextClipToMask(ctx, rect, alphaMask);
            [[NSColor blackColor] set];
            NSRectFill(rect);

            CGImageRelease(alphaMask);
        }

        return YES;
    }];
    [iconImage setTemplate:YES];
    [iconImage setName:iconName];
    return iconImage;
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

- (void)statusItemClicked:(id)sender
{
    [self updateStatusItemPositionInfo];
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
        [self.itsycalWindow orderOut:self];
    }
}

- (void)keyboardShortcutActivated
{
    // The user hit the keyboard shortcut. This is the same
    // as if the user had clicked the menubar icon.
    [self statusItemClicked:self];
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

- (void)updateClock
{
    [_clockTimer invalidate];

    // If the clock uses seconds, fire the timer after a second.
    // Otherwise, fire after 60 seconds. We could just fire every
    // second in either case, but we want to be as efficient as
    // possible and only fire when needed. Even firing every 60
    // seconds is too much if the format string doesn't contain
    // any time specifiers.
    NSTimeInterval clockInterval = _clockUsesSeconds ? 1 : 60;

    _clockTimer = [NSTimer timerWithTimeInterval:clockInterval target:self selector:@selector(updateMenubarIcon) userInfo:nil repeats:NO];

    // Align the timer's fireDate to real-time minutes or seconds.
    // We do this by subtracting the extra seconds or fractional
    // seconds from the fireDate.
    NSCalendarUnit extraUnits = _clockUsesSeconds ? NSCalendarUnitNanosecond : NSCalendarUnitSecond | NSCalendarUnitNanosecond;
    NSDateComponents *extraComponents = [_nsCal components:extraUnits fromDate:_clockTimer.fireDate];
    NSTimeInterval extraSeconds = (NSTimeInterval)extraComponents.nanosecond / (NSTimeInterval)NSEC_PER_SEC;
    extraSeconds += _clockUsesSeconds ? 0 : extraComponents.second;
    _clockTimer.fireDate = [_clockTimer.fireDate dateByAddingTimeInterval:-extraSeconds];

    // Add the timer to the main runloop.
    [[NSRunLoop mainRunLoop] addTimer:_clockTimer forMode:NSRunLoopCommonModes];
}

#pragma mark -
#pragma mark Custom clock format

- (void)clockFormatDidChange
{
    NSString *format = [[NSUserDefaults standardUserDefaults] stringForKey:kClockFormat];

    // Did the user set a custom clock format string?
    if (format != nil && ![format isEqualToString:@""]) {
        NSLog(@"Use custom clock format: [%@]", format);
        _clockUsesSeconds = [self formatContainsSecondsSpecifier:format];
        _statusItem.button.imagePosition = NSImageLeft;
        _clockFormat = format;
    }
    else {
        NSLog(@"Use normal icon");
        [_clockTimer invalidate];
        _clockTimer = nil;
        _statusItem.button.title = @"";
        _statusItem.button.imagePosition = NSImageOnly;
        _clockFormat = nil;
    }
    [self updateMenubarIcon];
}

- (BOOL)formatContainsSecondsSpecifier:(NSString *)format
{
    // The seconds specifier is an s-character. Does format
    // contain an s that isn't inside a quoted string? A
    // quoted string is delimited by single-quote chars.

    __block BOOL secondsSpecifierFound = NO;
    __block BOOL insideQuotedString = NO;

    // First, remove adjacent pairs of single-quotes. They
    // represent single-quote literals. Removing them makes
    // parsing for quoted strings much easier.
    NSString *fmt = [format stringByReplacingOccurrencesOfString:@"''" withString:@""];

    // Iterate through fmt looking for an s that isn't in a quoted string.
    [fmt enumerateSubstringsInRange: NSMakeRange(0, [fmt length]) options: NSStringEnumerationByComposedCharacterSequences usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {

        // Did we find an s that isn't inside a quoted string?
        if (insideQuotedString == NO && [substring isEqualToString:@"s"]) {
            secondsSpecifierFound = YES;
            *stop = YES;
        }
        // Are we inside a quoted string? They are delimited with single-quotes.
        else if ([substring isEqualToString:@"'"]) {
            insideQuotedString = !insideQuotedString;
        }
    }];
    return secondsSpecifierFound;
}

#pragma mark -
#pragma mark Notifications

- (void)fileNotifications
{
    // Day changed notification
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        MoDate today = [self todayDate];
        _moCal.todayDate = today;
        _moCal.selectedDate = today;
        [self updateMenubarIcon];
    }];
    
    // Timezone changed notification
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemTimeZoneDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self updateMenubarIcon];
        [_ec refetchAll];
    }];
    
    // Locale notifications
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self updateMenubarIcon];
    }];
    
    // System clock notification
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemClockDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self updateMenubarIcon];
    }];

    // Wake from sleep notification
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(updateMenubarIcon) name:NSWorkspaceDidWakeNotification object:nil];

    // Observe NSUserDefaults for preference changes
    for (NSString *keyPath in @[kShowEventDays, kUseOutlineIcon, kShowMonthInIcon, kShowDayOfWeekInIcon, kClockFormat]) {
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
    }
}

#pragma mark -
#pragma mark NSUserDefaults observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:kShowEventDays]) {
        [self updateAgenda];
    }
    else if ([keyPath isEqualToString:kUseOutlineIcon] ||
             [keyPath isEqualToString:kShowMonthInIcon] ||
             [keyPath isEqualToString:kShowDayOfWeekInIcon]) {
        [self updateMenubarIcon];
    }
    else if ([keyPath isEqualToString:kClockFormat]) {
        [self clockFormatDidChange];
    }
}

@end
