//
//  MoView.m
//  
//
//  Created by Sanjay Madan on 3/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoView.h"

@implementation MoView

void commonInitForMoView(MoView *moView)
{
    moView.viewIsOpaque = YES;
    moView.backgroundColor = [NSColor colorWithWhite:0.95 alpha:1];
    moView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        commonInitForMoView(self);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        commonInitForMoView(self);
    }
    return self;
}

- (BOOL)isOpaque { return self.viewIsOpaque; }

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.backgroundColor) {
        [self.backgroundColor set];
        NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
    }
}

@end
