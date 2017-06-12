//
//  MoCalCell.m
//
//
//  Created by Sanjay Madan on 12/3/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoCalCell.h"
#import "ItsyColors.h"

@implementation MoCalCell

static NSColor *kTodayCellColor=nil, *kHoveredCellColor=nil, *kSelectedCellColor=nil, *kDotColor=nil;

+ (void)initialize
{
    kTodayCellColor = [ItsyColors getHighlightColor];
    kHoveredCellColor = [ItsyColors getHoverColor];
    kSelectedCellColor = [ItsyColors getBorderColor];
}

- (instancetype)init
{
    self = [super initWithFrame:NSMakeRect(0, 0, kMoCalCellWidth, kMoCalCellHeight)];
    if (self) {
        _textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [_textField setFont:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular]];
        [_textField setTextColor:[ItsyColors getPrimaryTextColor]];
        [_textField setBezeled:NO];
        [_textField setEditable:NO];
        [_textField setAlignment:NSTextAlignmentCenter];
        [_textField setDrawsBackground:NO];
        [_textField setTranslatesAutoresizingMaskIntoConstraints:NO];

        [self addSubview:_textField];

        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_textField]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_textField)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-2-[_textField]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_textField)]];
    }
    return self;
}

- (void)setIsToday:(BOOL)isToday
{
    if (isToday != _isToday) {
        _isToday = isToday;
        [self setNeedsDisplay:YES];
    }
}

- (void)setIsSelected:(BOOL)isSelected
{
    if (isSelected != _isSelected) {
        _isSelected = isSelected;
        [self setNeedsDisplay:YES];
    }
}

- (void)setIsHovered:(BOOL)isHovered
{
    if (isHovered != _isHovered) {
        _isHovered = isHovered;
        [self setNeedsDisplay:YES];
    }
}

- (void)setHasDot:(BOOL)hasDot
{
    if (hasDot != _hasDot) {
        _hasDot = hasDot;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.isToday) {
        [kTodayCellColor set];
        NSRect r = NSInsetRect(self.bounds, 2, 2);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3];
        [p setLineWidth:2];
        [p stroke];
    }
    else if (self.isSelected) {
        [kSelectedCellColor set];
        NSRect r = NSInsetRect(self.bounds, 2.5, 2.5);
        [[NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3] stroke];
    }
    else if (self.isHovered) {
        [kHoveredCellColor set];
        NSRect r = NSInsetRect(self.bounds, 2.5, 2.5);
        [[NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3] stroke];
        [[kHoveredCellColor colorWithAlphaComponent:0.1] set];
        [[NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3] fill];
    }
    if (self.hasDot) {
        [self.textField.textColor set];
        NSRect r = NSMakeRect(0, 0, 3, 3);
        r.origin.x = self.bounds.origin.x + kMoCalCellWidth/2.0 - 1.5;
        r.origin.y = self.bounds.origin.y + 5;
        [[NSBezierPath bezierPathWithOvalInRect:r] fill];
    }
}

@end
