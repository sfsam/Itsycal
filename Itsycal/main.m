//
//  main.m
//  Moon
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // NSApplication's delegate is weak, so keep a strong reference.
        static AppDelegate *appDelegate;
        appDelegate = [AppDelegate new];
        NSApplication.sharedApplication.delegate = appDelegate;
    }
    return NSApplicationMain(argc, argv);
}
