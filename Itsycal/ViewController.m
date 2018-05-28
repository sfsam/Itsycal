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
#import "PrefsVC.h"
#import "PrefsGeneralVC.h"
#import "PrefsAppearanceVC.h"
#import "PrefsAboutVC.h"
#import "TooltipViewController.h"
#import "MoButton.h"
#import "MoVFLHelper.h"
#import "Sparkle/SUUpdater.h"

@implementation ViewController
{
    EventCenter   *_ec;
    MoCalendar    *_moCal;
    NSCalendar    *_nsCal;
    NSStatusItem  *_statusItem;
    MoButton      *_btnAdd, *_btnCal, *_btnOpt, *_btnPin;
    NSWindowController    *_prefsWC;
    AgendaViewController  *_agendaVC;
    NSLayoutConstraint    *_bottomMargin;
    NSDateFormatter       *_iconDateFormatter;
    NSTimer   *_pastEventsTimer;
    NSTimer   *_clockTimer;
    NSString  *_clockFormat;
    BOOL       _clockUsesSeconds;
    BOOL       _clockUsesTime;
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

    // Constraints
    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:nil views:NSDictionaryOfVariableBindings(_moCal, _btnAdd, _btnCal, _btnOpt, _btnPin, agenda)];
    [vfl :@"H:|[_moCal]|"];
    [vfl :@"H:|[agenda]|"];
    [vfl :@"H:|-6-[_btnAdd]-(>=0)-[_btnPin]-10-[_btnCal]-10-[_btnOpt]-6-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"V:|[_moCal]-6-[_btnOpt]"];
    [vfl :@"V:[agenda]-(-1)-|"];
    
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

    [self updatePastEventsTimer];
    
    // Now that everything else is set up, we file for notifications.
    // Some of the notification handlers rely on stuff we just set up.
    [self fileNotifications];

    [_moCal bind:@"showWeeks" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowWeeks] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_moCal bind:@"showEventDots" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_moCal bind:@"highlightedDOWs" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHighlightedDOWs] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_moCal bind:@"weekStartDOW" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWeekStartDOW] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_agendaVC bind:@"showLocation" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowLocation] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // A very ugly and questionable hack. Maybe it doesn't work. It
    // shouldn't work. But I think it might. Somehow prevents(?!?)
    // defaults from temporarily changing to NULL and then reverting
    // back after the first access. The bug seems random and hard to
    // replicate so I don't know if (or why) this works. The idea is
    // a bogus first access will prevent the bug from happening when
    // the user changes defaults the first time.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"WakeUpUserDefaults"];
    [defaults synchronize];
    [defaults removeObjectForKey:@"WakeUpUserDefaults"];
    [defaults synchronize];
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _btnPin.state = [defaults boolForKey:kPinItsycal] ? NSOnState : NSOffState;
    _moCal.showWeeks = [defaults boolForKey:kShowWeeks];

    [self.itsycalWindow makeFirstResponder:_moCal];
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    [self positionItsycalWindow];
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
        [[NSUserDefaults standardUserDefaults] setBool:!_moCal.showWeeks forKey:kShowWeeks];
    }
    else if (keyChar == '.' && noFlags) {
        [[NSUserDefaults standardUserDefaults] setBool:!_agendaVC.showLocation forKey:kShowLocation];
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
    // Was prefs window open in the past and then hidden when
    // app became inactive? This prevents it from reappearing.
    [_prefsWC close];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if (_ec.calendarAccessGranted == NO) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Calendar access was denied.", @"");
        alert.informativeText = NSLocalizedString(@"Itsycal is more useful when you allow it to add events to your calendars. You can change this setting in System Preferences › Security & Privacy › Privacy.", @"");
        [alert runModal];
        return;
    }
    
    // Confirm that there are calendars which can be modified.
    BOOL atLeastOneModifiableCalendar = NO;
    for (id obj in [_ec sourcesAndCalendars]) {
        if ([obj isKindOfClass:[CalendarInfo class]] && 
            ((CalendarInfo *)obj).calendar.allowsContentModifications) {
            atLeastOneModifiableCalendar = YES;
            break;
        }
    }
    if (atLeastOneModifiableCalendar == NO) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"There are no modifiable calendars.", @"");
        alert.informativeText = NSLocalizedString(@"Itsycal cannot create a new event unless there is at least one calendar you have permission to modify.", @"");
        [alert runModal];
        return;
    }

    EventViewController *eventVC = [EventViewController new];
    eventVC.ec = _ec;
    eventVC.cal = _nsCal;
    eventVC.title = @"";
    eventVC.calSelectedDate = MakeNSDateWithDate(_moCal.selectedDate, _nsCal);
    [self presentViewControllerAsModalWindow:eventVC];
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

- (void)showPrefs:(id)sender
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if (!_prefsWC) {
        // VCs for each tab in prefs panel.
        PrefsGeneralVC *prefsGeneralVC = [PrefsGeneralVC new];
        PrefsAppearanceVC *prefsAppearanceVC = [PrefsAppearanceVC new];
        PrefsAboutVC *prefsAboutVC = [PrefsAboutVC new];
        prefsGeneralVC.ec = _ec;
        prefsGeneralVC.title = NSLocalizedString(@"General", @"General prefs tab label");
        prefsAppearanceVC.title = NSLocalizedString(@"Appearance", @"Appearance prefs tab label");
        prefsAboutVC.title = NSLocalizedString(@"About", @"About prefs tab label");
        // prefsVC is the container VC the tab VCs.
        PrefsVC *prefsVC = [PrefsVC new];
        prefsVC.childViewControllers = @[prefsGeneralVC, prefsAppearanceVC, prefsAboutVC];
        // Create prefs WC.
        NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSZeroRect styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable) backing:NSBackingStoreBuffered defer:NO];
        _prefsWC = [[NSWindowController alloc] initWithWindow:panel];
        _prefsWC.contentViewController = prefsVC;
        _prefsWC.window.contentView.wantsLayer = YES;
        [_prefsWC.window center];
    }
    [_prefsWC showWindow:self];
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

    // Use monospaced font in case user sets custom clock format
    // so the status item doesn't move when the time changes.
    // We modify the default font with a font descriptor instead
    // of using +monospacedDigitSystemFontOfSize:weight: because
    // we get slightly darker looking ':' characters this way.
    NSFontDescriptor *fontDesc = [_statusItem.button.font fontDescriptor];
    fontDesc = [fontDesc fontDescriptorByAddingAttributes:@{NSFontFeatureSettingsAttribute: @[@{NSFontFeatureTypeIdentifierKey: @(kNumberSpacingType), NSFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}]}];
    _statusItem.button.font = [NSFont fontWithDescriptor:fontDesc size:0];

    // Remember item position in menubar. (@pskowronek (Github))
    [_statusItem setAutosaveName:@"ItsycalStatusItem"];

    [self clockFormatDidChange];
    [self updateMenubarIcon];
    [self positionItsycalWindow];

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
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kHideIcon]) {
        _statusItem.button.image = nil;
        _statusItem.button.imagePosition = NSNoImage;
    }
    else {
        _statusItem.button.image = [self iconImageForText:[self iconText]];
        _statusItem.button.imagePosition = _clockFormat ? NSImageLeft : NSImageOnly;
    }
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
    NSFont *font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightBold];
    CGRect textRect = [[[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: font}] boundingRectWithSize:CGSizeMake(999, 999) options:0 context:nil];

    // Icon width is at least 23 pts with 3 pt outside margins, 4 pt inside margins.
    CGFloat width = MAX(3 + 4 + ceilf(NSWidth(textRect)) + 4 + 3, 23);
    CGFloat height = 16;
    iconImage = [NSImage imageWithSize:NSMakeSize(width, height) flipped:NO drawingHandler:^BOOL (NSRect rect) {

        // Get image's context.
        CGContextRef const ctx = [[NSGraphicsContext currentContext] graphicsPort];

        if (useOutlineIcon) {

            // Draw outlined icon image.

            [[NSColor blackColor] set];
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 3.5, 0.5) xRadius:2 yRadius:2] stroke];

            // Turning off smoothing looks better (why??).
            CGContextSetShouldSmoothFonts(ctx, false);

            // Draw text.
            NSMutableParagraphStyle *pstyle = [NSMutableParagraphStyle new];
            pstyle.alignment = NSTextAlignmentCenter;
            [text drawInRect:NSOffsetRect(rect, 0, -1) withAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:11.5 weight:NSFontWeightSemibold], NSParagraphStyleAttributeName: pstyle, NSForegroundColorAttributeName: [NSColor blackColor]}];
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
            [text drawInRect:NSOffsetRect(deviceRect, 0, -1) withAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:fontSize weight:NSFontWeightBold], NSForegroundColorAttributeName: [NSColor blackColor], NSParagraphStyleAttributeName: pstyle}];

            // Switch back to the image's context.
            [NSGraphicsContext restoreGraphicsState];
            CGContextRelease(maskContext);

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

- (void)positionItsycalWindow
{
    NSRect statusItemFrame = [_statusItem.button.window convertRectToScreen:_statusItem.button.frame];

    // Hack alert:
    // Which screen is the status item on? I'd like to just use
    // _statusItem.button.window.screen, but that property is nil
    // when the user is working with a full screen app: the menu
    // bar is hidden and so the status item is offscreen.
    // Alternatively, I'd like to use [NSScreen mainscreen], but
    // that method seems to give the wrong answer when the user
    // is working on an external monitor with a full screen app.
    // So... I iterate over all the screens and see which one
    // contains the statusItem's origin. I adjust the origin
    // down a bit to account for the case where the menu bar is
    // hidden (as it is when an app is in fullscreen mode) as
    // the system *currently* places the status item just above
    // its screen. This isn't documented behavior and so might
    // not work in the future.
    NSScreen *statusItemScreen = [NSScreen mainScreen];
    NSPoint testPoint = statusItemFrame.origin;
    testPoint.y -= 100;
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(testPoint, screen.frame)) {
            statusItemScreen = screen;
            break;
        }
    }
    CGFloat screenMaxX = NSMaxX(statusItemScreen.frame);

    // Constrain the menu item's frame to be no higher than the top
    // of the screen. For some reason, when an app is in fullscreen
    // mode sometimes the menu item frame is reported to be *above*
    // the top of the screen. The result is that the calendar is
    // shown clipped at the top. Prevent that by constraining the
    // top of the menu item to be at most the top of the screen.
    statusItemFrame.origin.y = MIN(statusItemFrame.origin.y, NSMaxY(statusItemScreen.frame));

    [self.itsycalWindow positionRelativeToRect:statusItemFrame screenMaxX:screenMaxX];
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self positionItsycalWindow];
    });
}

- (void)statusItemClicked:(id)sender
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
    if ([self.itsycalWindow occlusionState] & NSWindowOcclusionStateVisible) {
        [self.itsycalWindow orderOut:self];
    }
    else {
        [self showItsycalWindow];
    }
}

#pragma mark -
#pragma mark Window management

- (ItsycalWindow *)itsycalWindow
{
    return (ItsycalWindow *)self.view.window;
}

- (void)showItsycalWindow
{
    [[NSApplication sharedApplication] unhideWithoutActivation];
    [self positionItsycalWindow];
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
    [self positionItsycalWindow];
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
    
    // Make a string showing the event title and duration.
    static NSDateIntervalFormatter *durationFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        durationFormatter = [NSDateIntervalFormatter new];
        durationFormatter.dateStyle = NSDateIntervalFormatterMediumStyle;
    });
    NSDate *endDate = event.endDate;
    if (event.isAllDay) {
        // EKEvent allDay events go from 12 AM to 12 AM. So, a one-day event
        // will just barely span two days. For example, a one-day event on Aug 4
        // results in a duration of Aug 4-5. By subtracting some time, we get the
        // duration in days we would expect.
        endDate = [_nsCal dateByAddingUnit:NSCalendarUnitHour value:-4 toDate:event.endDate options:0];
        durationFormatter.timeStyle = NSDateIntervalFormatterNoStyle;
    }
    else {
        durationFormatter.timeStyle = NSDateIntervalFormatterShortStyle;
    }
    durationFormatter.timeStyle = event.isAllDay ? NSDateIntervalFormatterNoStyle : NSDateIntervalFormatterShortStyle;
    NSString *title = event.title == nil ? @"" : event.title;
    NSString *duration = [durationFormatter stringFromDate:event.startDate toDate:endDate];
    NSString *eventString = [NSString stringWithFormat:@"%@\n%@", title, duration];

    BOOL eventRepeats = event.hasRecurrenceRules;
    
    // Ask the user to confirm they want to delete this event (or future events).
    NSAlert *alert = [NSAlert new];
    if (eventRepeats == YES) {
        alert.messageText = NSLocalizedString(@"You're deleting an event.", @"");
        alert.informativeText = [NSString stringWithFormat:@"%@\n\n%@", eventString, NSLocalizedString(@"Do you want to delete this and all future occurrences of this event, or only the selected occurrence?", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Delete Only This Event", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Delete All Future Events", @"")];
    }
    else {
        alert.messageText = NSLocalizedString(@"Are you sure you want to delete this event?", @"");
        alert.informativeText = eventString;
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
    days = MIN(MAX(days, 0), 9); // days is in range 0..9
    // days == 8 really means 14; 9 really means 31
    if (days == 8) days = 14; else if (days == 9) days = 31;
    _agendaVC.events = [_ec datesAndEventsForDate:_moCal.selectedDate days:days];
    [_agendaVC reloadData];
    _bottomMargin.constant = _agendaVC.events.count == 0 ? 26 : 30;
}

- (void)updatePastEventsTimer
{
    [_pastEventsTimer invalidate];
    
    // Timer fireDate is 1 second after the next minute.
    
    NSCalendarUnit units = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    NSDateComponents *components = [_nsCal components:units fromDate:[NSDate new]];
    components.minute += 1;
    components.second  = 1;
    NSDate *fireDate = [_nsCal dateFromComponents:components];
    
    __weak typeof(self) weakSelf = self;
    _pastEventsTimer = [[NSTimer alloc] initWithFireDate:fireDate interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf updatePastEventsTimer];
    }];
    
    // Tolerance lets system wake up more efficiently at the expense of some accuracy.
    _pastEventsTimer.tolerance = 6;
    
    // Add the timer to the main runloop.
    [[NSRunLoop mainRunLoop] addTimer:_pastEventsTimer forMode:NSRunLoopCommonModes];
    
    [_agendaVC dimEventsIfNecessary];
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
    
    if (!_clockUsesTime) return;
    
    // If the clock uses seconds, fire the timer after a second.
    // Otherwise, fire after 60 seconds. We could just fire every
    // second in either case, but we want to be as efficient as
    // possible and only fire when needed.

    NSCalendarUnit units = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    
    if (_clockUsesSeconds) { units |= NSCalendarUnitSecond; }
    
    NSDateComponents *components = [_nsCal components:units fromDate:[NSDate new]];
    
    if (_clockUsesSeconds) { components.second += 1; }
    else                   { components.minute += 1; }

    NSDate *fireDate = [_nsCal dateFromComponents:components];

    __weak typeof(self) weakSelf = self;
    _clockTimer = [[NSTimer alloc] initWithFireDate:fireDate interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf updateMenubarIcon];
    }];

    // Tolerance lets system wake up more efficiently at the expense of some accuracy.
    _clockTimer.tolerance = 0.3;

    // Add the timer to the main runloop.
    [[NSRunLoop mainRunLoop] addTimer:_clockTimer forMode:NSRunLoopCommonModes];
}

#pragma mark -
#pragma mark Custom clock format

- (void)clockFormatDidChange
{
    NSString *format = [[NSUserDefaults standardUserDefaults] stringForKey:kClockFormat];

    // -observeValueForKeyPath:ofObject:change:context: sends
    // redundant change notifications ever since binding prefs
    // textfield to kClockFormat. If clock format hasn't changed,
    // ignore this redundant change notification.
    if ((format == nil && _clockFormat == nil) ||
        [format isEqualToString:_clockFormat]) {
        return;
    }

    // Did the user set a custom clock format string?
    if (format != nil && ![format isEqualToString:@""]) {
        NSLog(@"Use custom clock format: [%@]", format);
        [self processFormatForTimeAndSecondsSpecifiers:format];
        _clockFormat = format;
    }
    else {
        NSLog(@"Use normal icon");
        [_clockTimer invalidate];
        _clockTimer = nil;
        _clockFormat = nil;
        _statusItem.button.title = @"";
    }
    [self updateMenubarIcon];
}

- (void)processFormatForTimeAndSecondsSpecifiers:(NSString *)format
{
    // A time specifier is one of the following: a, H, h, K, k, j, m, s.
    // The seconds specifier is an s-character. Does format contain
    // a time specifier or s that isn't inside a quoted string? a quoted
    // string is delimited by single-quote chars.

    NSString *timeSpecifiers = @"aHhKkjms";
    
    __block BOOL timeSpecifierFound = NO;
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
            timeSpecifierFound = YES;
            *stop = YES;
        }
        // Did we find a time specifier that isn't inside a quoted string?
        else if (insideQuotedString == NO && [timeSpecifiers containsString:substring]) {
            timeSpecifierFound = YES;
        }
        // Are we inside a quoted string? They are delimited with single-quotes.
        else if ([substring isEqualToString:@"'"]) {
            insideQuotedString = !insideQuotedString;
        }
    }];
    _clockUsesTime = timeSpecifierFound;
    _clockUsesSeconds = secondsSpecifierFound;

    if (_clockUsesTime) NSLog(@"Format has time");
    if (_clockUsesSeconds) NSLog(@"Format has seconds");
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
        [_ec refetchAll];
    }];

    // Wake from sleep notification
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(updateMenubarIcon) name:NSWorkspaceDidWakeNotification object:nil];

    // Observe NSUserDefaults for preference changes
    for (NSString *keyPath in @[kShowEventDays, kUseOutlineIcon, kShowMonthInIcon, kShowDayOfWeekInIcon, kHideIcon, kClockFormat]) {
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
             [keyPath isEqualToString:kShowDayOfWeekInIcon] ||
             [keyPath isEqualToString:kHideIcon]) {
        [self updateMenubarIcon];
    }
    else if ([keyPath isEqualToString:kClockFormat]) {
        [self clockFormatDidChange];
    }
}

@end
