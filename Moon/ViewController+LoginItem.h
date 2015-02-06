//
//  ViewController+LoginItem.h
//  Moon
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewController.h"

@interface ViewController (LoginItem)

- (BOOL)isLoginItemEnabled;
- (void)enableLoginItem:(BOOL)enable;

@end
