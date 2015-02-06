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
    NSWindowController *_wc;
}

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"PinItsycal": @(NO),
        @"ShowWeeks": @(NO)}];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _wc = [[NSWindowController alloc] initWithWindow:[ItsycalWindow  new]];
    _wc.contentViewController = [ViewController new];
    _wc.window.delegate = (ViewController *)_wc.contentViewController;
    [_wc showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

@end
