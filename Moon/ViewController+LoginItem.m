//
//  ViewController+LoginItem.m
//  Moon
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "ViewController+LoginItem.h"

@implementation ViewController (LoginItem)

- (BOOL)isLoginItemEnabled
{
    BOOL isEnabled = NO;
    
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef) {
        UInt32 seedValue;
        NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
        for (id item in loginItems) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            CFURLRef thePath = LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL);            
            if (thePath) {
                NSURL *thePathUrl = CFBridgingRelease(thePath);
                if ([[thePathUrl path] hasPrefix:appPath]) {
                    isEnabled = YES;
                    break;
                }
            }
        }
        CFRelease(loginItemsRef);
    }
    return isEnabled;
}

- (void)enableLoginItem:(BOOL)enable;
{
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef) {
        if (enable) {
            [self enableLoginItemWithLoginItemsReference:loginItemsRef];
        }
        else {
            [self disableLoginItemWithLoginItemsReference:loginItemsRef];
        }
        CFRelease(loginItemsRef);
    }
}

#pragma mark -
#pragma mark Private

- (void)enableLoginItemWithLoginItemsReference:(LSSharedFileListRef )loginItemsRef
{
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    
    // We call LSSharedFileListInsertItemURL to insert the item at the bottom of Login Items list.
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
    LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
    if (item != NULL) CFRelease(item);
}

- (void)disableLoginItemWithLoginItemsReference:(LSSharedFileListRef )loginItemsRef
{
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    
    // Grab the contents of the shared file list (LSSharedFileListItemRef objects)
    // and pop it in an array so we can iterate through it to find our item.
    UInt32 seedValue;
    NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
    for (id item in loginItems) {
        LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
        CFURLRef thePath = LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL);
        if (thePath) {
            NSURL *thePathUrl = CFBridgingRelease(thePath);
            if ([[thePathUrl path] hasPrefix:appPath]) {
                LSSharedFileListItemRemove(loginItemsRef, itemRef); // Deleting the item
            }
        }
    }
}

@end
