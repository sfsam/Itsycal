//
//  PrefsViewController.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EventCenter;

@interface PrefsViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, weak) EventCenter *ec;

@end
