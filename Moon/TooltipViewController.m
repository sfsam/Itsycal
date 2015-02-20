//
//  TooltipViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "TooltipViewController.h"
#import "EventCenter.h"

@implementation TooltipViewController

- (void)toolTipForDate:(MoDate)date
{
    self.events = [self.ec eventsForDate:date];
    [self reloadData];
}

@end
