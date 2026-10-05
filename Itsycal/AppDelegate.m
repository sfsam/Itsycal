//
//  AppDelegate.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "AppDelegate.h"
#import "Itsycal.h"
#import "ItsycalWindow.h"
#import "ViewController.h"
#import "Themer.h"
#import "Sizer.h"
#import "MoUtils.h"
#import "MASShortcut/Shortcut.h"
#import "Sparkle/SUUpdater.h"

@implementation AppDelegate
{
    NSWindowController *_wc;
    ViewController *_vc;
}

+ (void)initialize
{
    // Get the default firstWeekday for user's locale.
    // User can change this in preferences.
    NSCalendar *cal = [NSCalendar autoupdatingCurrentCalendar];
    NSInteger weekStartDOW = MIN(MAX(cal.firstWeekday - 1, 0), 6);
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        kPinItsycal:           @(NO),
        kShowWeeks:            @(NO),
        kHighlightedDOWs:      @0,
        kShowEventDays:        @7,
        kWeekStartDOW:         @(weekStartDOW), // Sun=0, Mon=1,... (MoCalendar.h)
        kShowMonthInIcon:      @(NO),
        kShowDayOfWeekInIcon:  @(NO),
        kShowEventDots:        @(YES),
        kUseColoredDots:       @(YES),
        kThemePreference:      @0, // System=0, Light=1, Dark=2
        kHideIcon:             @(NO),
        kShowLocation:         @(NO),
        kDoNotDrawOutlineAroundCurrentMonth: @(NO)
    }];
    
    // Constrain kShowEventDays to values 0...9 in (unlikely) case it is invalid.
    NSInteger validDays = MIN(MAX([defaults integerForKey:kShowEventDays], 0), 9);
    [defaults setInteger:validDays forKey:kShowEventDays];
    
    // Set kThemePreference to defaultThemePref in the unlikely case it's invalid.
    NSInteger themePref = [defaults integerForKey:kThemePreference];
    if (themePref < 0 || themePref > 2) {
        [defaults setInteger:0 forKey:kThemePreference];
    }
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    NSApp.mainMenu = [self mainMenu];

    // Create Sparkle's updater. This starts its update cycle.
    [SUUpdater sharedUpdater];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Ensure the user has moved Itsycal to the /Applications folder.
    // Having the user manually move Itsycal to /Applications turns off
    // Gatekeeper Path Randomization (introduced in 10.12) and allows
    // Itsycal to be updated with Sparkle. :P
#ifndef DEBUG
    [self checkIfRunFromApplicationsFolder];
#endif

    // Initialize the 'Theme' global variable which can be
    // used throught the app instead of '[Themer shared]'.
    [Themer shared];

    // Initialize the 'SizePref' global variable which can be
    // used throught the app instead of '[Sizer shared]'.
    [Sizer shared];

    // Create our Application Support folder if it doesn't exist.
    // ~/Library/Application Support/com.mowglii.ItsycalApp/
    NSURL *url = [[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    if (url) {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        url = [url URLByAppendingPathComponent:bundleID isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
    }

    // Register keyboard shortcut.
    [[MASShortcutBinder sharedBinder] setBindingOptions:@{NSValueTransformerNameBindingOption: MASDictionaryTransformerName}];
    [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:kKeyboardShortcut toAction:^{
         [self->_vc keyboardShortcutActivated];
     }];

    // Establish the binding to NSUserDefaultsController. This call
    // must be made BEFORE the window is created because sizes are
    // used when initializing views.
    [SizePref bind:@"sizePreference" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kSizePreference] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // The window's contentView draws the window, so put the view
    // controller's view inside it rather than setting the window's
    // contentViewController (which would replace the contentView).
    _vc = [ViewController new];
    _wc = [[NSWindowController alloc] initWithWindow:[ItsycalWindow  new]];
    NSView *contentView = _wc.window.contentView;
    NSLayoutGuide *safeArea = contentView.safeAreaLayoutGuide;
    [contentView addSubview:_vc.view];
    [NSLayoutConstraint activateConstraints:@[
        [_vc.view.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [_vc.view.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [_vc.view.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [_vc.view.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
    ]];
    _wc.window.delegate = _vc;
    
    // Establish the binding to NSUserDefaultsController. On macOS
    // 10.14+, it is crucial for this call to be made AFTER the window
    // is created because Theme instantiation relies on checking a
    // property on the window to determine its appearance.
    [Theme bind:@"themePreference" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kThemePreference] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [_vc removeStatusItem];
    [[MASShortcutMonitor sharedMonitor] unregisterAllShortcuts];
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls
{
    if (urls.count >= 1) {
        // We can only handle showing one date at a time, so we pick the first one
        NSURL *url = urls[0];
        if ([url.host isEqualToString:@"date"] && url.pathComponents.count == 2) {
            NSString *dateString = url.pathComponents[1];
            
            if ([dateString isEqualToString:@"now"]) {
                [_vc dateURLReceived:[NSDate new]];
            } else {
                NSDateFormatter *format = [NSDateFormatter new];
                format.dateFormat = @"yyyy-MM-dd";
                NSDate *date = [format dateFromString:dateString];
                
                if (date) {
                    [_vc dateURLReceived:date];
                }
            }
        }
    }
}

#pragma mark -
#pragma mark Applications folder check

- (void)checkIfRunFromApplicationsFolder
{
    // This check can be short-circuited.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kAllowOutsideApplicationsFolder]) {
        return;
    }
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSArray *applicationDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask | NSUserDomainMask, YES);
    for (NSString *appDir in applicationDirs) {
        if ([bundlePath hasPrefix:appDir]) {
            return; // Ok, Itsycal is being run from /Applications.
        }
    }
    // Itsycal is not being run from /Applications.
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Move Itsycal to the Applications folder", nil);
    alert.informativeText = [NSLocalizedString(@"Itsycal must be run from the Applications folder in order to work properly.\n\nPlease quit Itsycal, move it to the Applications folder, and relaunch.", nil) stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", bundlePath]];
    alert.icon = [NSImage imageNamed:@"move"];
    alert.showsHelp = YES;
    alert.delegate = self;
    [alert addButtonWithTitle:NSLocalizedString(@"Quit Itsycal", @"")];
    [alert runModal];
    [NSApp terminate:nil];
}

#pragma mark -
#pragma mark Main menu

// Itsycal is a menu bar app, so its main menu is never shown. But
// AppKit uses the main menu to handle standard keyboard shortcuts
// like ⌘C, ⌘V, ⌘Z, ⌘A, ⌘W, and ⌘Q. Since it's never shown, all the
// items go in a single submenu, and the titles aren't localized.
- (NSMenu *)mainMenu
{
    NSMenu *menu = [NSMenu new];
    [menu addItemWithTitle:@"Quit Itsycal" action:@selector(terminate:) keyEquivalent:@"q"];
    [menu addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
    // AppKit implements undo: and redo: (in NSWindow and NSTextView),
    // but no public header declares them, so look them up by name.
    [menu addItemWithTitle:@"Undo" action:NSSelectorFromString(@"undo:") keyEquivalent:@"z"];
    [menu addItemWithTitle:@"Redo" action:NSSelectorFromString(@"redo:") keyEquivalent:@"Z"];
    [menu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [menu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [menu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    NSMenuItem *pasteAsPlainText = [menu addItemWithTitle:@"Paste and Match Style" action:@selector(pasteAsPlainText:) keyEquivalent:@"v"];
    pasteAsPlainText.keyEquivalentModifierMask = NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagCommand;
    [menu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    NSMenu *mainMenu = [NSMenu new];
    [mainMenu addItemWithTitle:@"" action:NULL keyEquivalent:@""].submenu = menu;
    return mainMenu;
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
    NSURL *url = [NSURL URLWithString:@"https://mowglii.com/itsycal/appfolder.html"];
    [[NSWorkspace sharedWorkspace] openURL:url];
    return YES;
}

@end
