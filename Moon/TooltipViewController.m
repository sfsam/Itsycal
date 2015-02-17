//
//  TooltipViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "TooltipViewController.h"

@implementation TooltipViewController
{
    NSTextField *t;
}

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    
    t = [NSTextField new];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.textColor = [NSColor blackColor];
    t.bezeled = NO;
    t.editable = NO;
    t.drawsBackground = NO;

    [v addSubview:t];
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[t]-8-|" options:0 metrics:nil views:@{@"t":t}]];
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-4-[t]-4-|" options:0 metrics:nil views:@{@"t":t}]];
    
    self.view = v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)toolTipForDate:(MoDate)date
{
    t.stringValue = [NSString stringWithFormat:@"Jessie Char %d-%d-%d", date.year, date.month+1, date.day];
}

@end
