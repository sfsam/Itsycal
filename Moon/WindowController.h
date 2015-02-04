//
//  WindowController.h
//  Moon
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
 
 WindowController has these responsibilities:
 - show/hide/position the window
 - manage the status item
 - communicate with the menu extra
 - keep track of today
 
 */

@interface WindowController : NSWindowController <NSWindowDelegate>

- (void)startup;

@end
