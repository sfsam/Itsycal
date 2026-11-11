//
//  TooltipViewController.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AgendaViewController.h"
#import "TooltipController.h"

// Shows a calendar day's tooltip: its events, as the agenda shows that
// day's rows, without the date heading. When they don't all fit, the
// last row says how many more there are. Set nsCal, as for the agenda.
// One instance serves every day.
@interface TooltipViewController : AgendaViewController

// The tooltip content for a day's events (EventInfo objects). Making
// it changes nothing on screen: the events go into this view
// controller only when the tooltip lays the content out to show it.
- (id<TooltipContent>)tooltipContentForEvents:(NSArray *)events;

@end
