//
//  AgendaViewController.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/18/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoTableView.h"

@protocol AgendaDelegate;

@interface AgendaViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, MoTableViewDelegate>

@property (nonatomic, weak) NSCalendar *nsCal;
@property (nonatomic) MoTableView *tv;
@property (nonatomic) NSArray *events;
@property (nonatomic) NSColor *backgroundColor;
@property (nonatomic, weak) id<AgendaDelegate> delegate;

- (void)reloadData;

@end

@class EKEvent;

@protocol AgendaDelegate <NSObject>

@optional
- (void)agendaHoveredOverRow:(NSInteger)row;
- (void)agendaWantsToDeleteEvent:(EKEvent *)event;

@end
