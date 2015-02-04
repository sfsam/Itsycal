//
//  AppDelegate.m
//  Moon
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "AppDelegate.h"
#import "WindowController.h"
#import "ViewController.h"

@implementation AppDelegate
{
    WindowController *wc;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    wc = [WindowController new];
    wc.contentViewController = [ViewController new];
    [wc startup];
    [wc showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

@end
