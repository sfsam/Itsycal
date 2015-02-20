//
//  AgendaViewController.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/18/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AgendaViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic) NSArray *events;

- (void)reloadData;

@end
