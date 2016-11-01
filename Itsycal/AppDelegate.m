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
#import "MASShortcut/MASShortcutBinder.h"
#import "MASShortcut/MASShortcutMonitor.h"

@implementation AppDelegate
{
    NSWindowController  *_wc;
    ViewController      *_vc;
}

+ (void)initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        kPinItsycal:       @(NO),
        kShowWeeks:        @(NO),
        kHighlightWeekend: @(NO),
        kShowEventDays:    @7,
        kWeekStartDOW:     @0, // Sun=0, Mon=1,... (MoCalendar.h)
        kShowMonthInIcon:  @(NO),
        kShowDayOfWeekInIcon: @(NO)
    }];
    
    // Constrain kShowEventDays to values 0...7 in (unlikely) case it is invalid.
    NSInteger validDays = MIN(MAX([defaults integerForKey:kShowEventDays], 0), 7);
    [defaults setInteger:validDays forKey:kShowEventDays];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // On macOS 10.12+, ensure the user has moved Itsycal to the
    // /Applications folder. Having the user manually move Itsycal
    // to /Applications turns off Gatekeeper Path Randomization
    // and allows Itsycal to be updated with Sparkle. :P
    if (OSVersionIsAtLeast(10, 12, 0)) {
        [self checkIfRunFromApplicationsFolder];
    }
    
    // Register keyboard shortcut.
    [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:kKeyboardShortcut toAction:^{
         [_vc keyboardShortcutActivated];
     }];
    
    _vc = [ViewController new];
    _wc = [[NSWindowController alloc] initWithWindow:[ItsycalWindow  new]];
    _wc.contentViewController = _vc;
    _wc.window.delegate = _vc;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [_vc removeStatusItem];
    [[MASShortcutMonitor sharedMonitor] unregisterAllShortcuts];
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
    NSArray *applicationDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES);
    for (NSString *appDir in applicationDirs) {
        if ([bundlePath hasPrefix:appDir]) {
            return; // Ok, Itsycal is being run from /Applications.
        }
    }
    // Itsycal is not being run from /Applications.
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Move Itsycal to the Applications folder", nil);
    alert.informativeText = NSLocalizedString(@"Itsycal must be run from the Applications folder in order to work properly.\n\nPlease quit Itsycal, move it to the Applications folder, and relaunch.", nil);
    alert.icon = [NSImage imageNamed:@"move"];
    [alert addButtonWithTitle:NSLocalizedString(@"Quit Itsycal", @"")];
    [alert runModal];
    [NSApp terminate:nil];
}

@end
