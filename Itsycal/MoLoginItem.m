//
//  Created by Sanjay Madan on 12/9/16.
//  Copyright © 2016 Mowglii. All rights reserved.
//

#import "MoLoginItem.h"

// LSSharedFileList API was deprecated in macOS 10.11
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

BOOL MOIsLoginItemEnabled(void)
{
    BOOL isEnabled = NO;
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);

    if (loginItemsRef) {
        UInt32 seedValue;
        NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
        for (id item in loginItems) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
            if (pathURL && [pathURL.path hasPrefix:appPath]) {
                isEnabled = YES;
                break;
            }
        }
        CFRelease(loginItemsRef);
    }
    return isEnabled;
}

void MOEnableLoginItem(BOOL enable)
{
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);

    if (loginItemsRef) {
        if (enable) {
            // We call LSSharedFileListInsertItemURL to insert the item at the bottom of Login Items list.
            CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
            if (item != NULL) CFRelease(item);
        }
        else {
            // Grab the contents of the shared file list (LSSharedFileListItemRef objects)
            // and pop it in an array so we can iterate through it to find our item.
            UInt32 seedValue;
            NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
            for (id item in loginItems) {
                LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
                NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
                if (pathURL && [pathURL.path hasPrefix:appPath]) {
                    LSSharedFileListItemRemove(loginItemsRef, itemRef); // Deleting the item
                }
            }
        }
        CFRelease(loginItemsRef);
    }
}

#pragma clang diagnostic pop
