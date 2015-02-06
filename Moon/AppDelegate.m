//
//  AppDelegate.m
//  Moon
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "ItsycalWindow.h"

@implementation AppDelegate
{
    NSWindowController  *_wc;
    ViewController      *_vc;
}

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"PinItsycal":    @(NO),
        @"ShowWeeks":     @(NO),
        @"WeekStartDOW":  @0  // Sun=0, Mon=1,... (MoCalendar.h)
    }];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _vc = [ViewController new];
    _wc = [[NSWindowController alloc] initWithWindow:[ItsycalWindow  new]];
    _wc.contentViewController = _vc;
    _wc.window.delegate = _vc;
    [_wc showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

@end
