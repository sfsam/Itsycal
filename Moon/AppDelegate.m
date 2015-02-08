//
//  AppDelegate.m
//  Itsycal2
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "AppDelegate.h"
#import "Itsycal.h"
#import "ItsycalWindow.h"
#import "ViewController.h"
#import "MASShortcutBinder.h"
#import "MASShortcutMonitor.h"

@implementation AppDelegate
{
    NSWindowController  *_wc;
    ViewController      *_vc;
}

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kPinItsycal:   @(NO),
        kShowWeeks:    @(NO),
        kWeekStartDOW: @0 // Sun=0, Mon=1,... (MoCalendar.h)
    }];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Register keyboard shortcut.
    [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:kKeyboardShortcut toAction:^{
         [_vc keyboardShortcutActivated];
     }];
    
    _vc = [ViewController new];
    _wc = [[NSWindowController alloc] initWithWindow:[ItsycalWindow  new]];
    _wc.contentViewController = _vc;
    _wc.window.delegate = _vc;
    [_wc showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[MASShortcutMonitor sharedMonitor] unregisterAllShortcuts];
}

@end
