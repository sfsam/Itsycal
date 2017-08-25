//
//  TooltipViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "TooltipViewController.h"
#import "EventCenter.h"
#import "Themer.h"

@implementation TooltipViewController

- (BOOL)toolTipForDate:(MoDate)date
{
    self.backgroundColor = [[Themer shared] tooltipBackgroundColor];
    self.tv.enableHover = NO;
    self.tv.enclosingScrollView.hasVerticalScroller = NO; // in case user has System Prefs set to always show scroller
    self.events = [self.ec eventsForDate:date];
    if (self.events) {
        [self reloadData];
        return YES;
    }
    return NO;
}

@end
