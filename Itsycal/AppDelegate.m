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
        kPinItsycal:           @(NO),
        kShowWeeks:            @(NO),
        kHighlightedDOWs:      @0,
        kShowEventDays:        @7,
        kWeekStartDOW:         @0, // Sun=0, Mon=1,... (MoCalendar.h)
        kShowMonthInIcon:      @(NO),
        kShowDayOfWeekInIcon:  @(NO),
        kHideIcon:             @(NO)
    }];
    
    // Constrain kShowEventDays to values 0...7 in (unlikely) case it is invalid.
    NSInteger validDays = MIN(MAX([defaults integerForKey:kShowEventDays], 0), 7);
    [defaults setInteger:validDays forKey:kShowEventDays];
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

    // 0.11.1 introduced a new way to highlight columns in the calendar.
    [self weekendHighlightFixup];

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
    alert.informativeText = [NSLocalizedString(@"Itsycal must be run from the Applications folder in order to work properly.\n\nPlease quit Itsycal, move it to the Applications folder, and relaunch.", nil) stringByAppendingString:[NSString stringWithFormat:@"\n\n%@\n%@", bundlePath, applicationDirs]];
    alert.icon = [NSImage imageNamed:@"move"];
    [alert addButtonWithTitle:NSLocalizedString(@"Quit Itsycal", @"")];
    [alert runModal];
    [NSApp terminate:nil];
}

#pragma mark -
#pragma mark Weekend highlight fixup

// Itsycal 0.11.1 moves away from using a trio of possible defaults
// (HighlightWeekend, WeekendIsFridaySaturday, WeekendIsSaturdaySunday) and
// a hardcoded list of countries with Fri/Sat weekends to the method
// of allowing the user to specify highlighted DOWs. If the user had
// HighlightWeekend == YES, migrate their highlight settings. In either
// case, remove the old default keys.
- (void)weekendHighlightFixup
{
    NSArray *countriesWithFridaySaturdayWeekend = @[
        @"AF", @"DZ", @"BH", @"BD", @"EG", @"IQ", @"JO", @"KW", @"LY",
        @"MV", @"OM", @"PS", @"QA", @"SA", @"SD", @"SY", @"AE", @"YE"];
    NSString *countryCode = [NSLocale currentLocale].countryCode;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"HighlightWeekend"]) {
        if ([defaults boolForKey:@"WeekendIsFridaySaturday"] ||
            [countriesWithFridaySaturdayWeekend containsObject:countryCode]) {
            // Fri + Sat = (1<<5) + (1<<6) = 32 + 64 = 96
            [defaults setInteger:96 forKey:kHighlightedDOWs];
        }
        else {
            // Sat + Sun = (1<<6) + (1<<0) = 64 + 1 = 65
            [defaults setInteger:65 forKey:kHighlightedDOWs];
        }
    }
    [defaults removeObjectForKey:@"HighlightWeekend"];
    [defaults removeObjectForKey:@"WeekendIsFridaySaturday"];
    [defaults removeObjectForKey:@"WeekendIsSaturdaySunday"];
}

@end
