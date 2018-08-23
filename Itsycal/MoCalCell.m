//
//  MoCalCell.m
//
//
//  Created by Sanjay Madan on 12/3/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoCalCell.h"
#import "Themer.h"
#import "Sizer.h"

@implementation MoCalCell
{
    NSLayoutConstraint *_textFieldVerticalSpace;
}

- (instancetype)init
{
    CGFloat sz = [[Sizer shared] cellSize];
    self = [super initWithFrame:NSMakeRect(0, 0, sz, sz)];
    if (self) {
        _textField = [NSTextField labelWithString:@""];
        [_textField setFont:[NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightMedium]];
        [_textField setTextColor:[NSColor blackColor]];
        [_textField setAlignment:NSTextAlignmentCenter];
        [_textField setTranslatesAutoresizingMaskIntoConstraints:NO];

        [self addSubview:_textField];

        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_textField]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_textField)]];
        
        _textFieldVerticalSpace = [NSLayoutConstraint constraintWithItem:_textField attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:[[Sizer shared] cellTextFieldVerticalSpace]];
        [self addConstraint:_textFieldVerticalSpace];

        
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)sizeChanged:(id)sender
{
    [_textField setFont:[NSFont systemFontOfSize:[[Sizer shared] fontSize] weight:NSFontWeightMedium]];
    _textFieldVerticalSpace.constant = [[Sizer shared] cellTextFieldVerticalSpace];
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
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.isToday) {
        [[[Themer shared] todayCellColor] set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3];
        [p setLineWidth:2];
        [p stroke];
    }
    else if (self.isSelected) {
        [[[Themer shared] selectedCellColor] set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3];
        [p setLineWidth:2];
        [p stroke];
    }
    else if (self.isHovered) {
        [[[Themer shared] hoveredCellColor] set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3];
        [p setLineWidth:2];
        [p stroke];
    }
    if (self.hasDot) {
        CGFloat sz = [[Sizer shared] cellSize];
        CGFloat dotWidth = [[Sizer shared] cellDotWidth];
        [self.textField.textColor set];
        NSRect r = NSMakeRect(0, 0, dotWidth, dotWidth);
        r.origin.x = self.bounds.origin.x + sz/2.0 - dotWidth/2.0;
        r.origin.y = self.bounds.origin.y + dotWidth + 2;
        [[NSBezierPath bezierPathWithOvalInRect:r] fill];
    }
}

@end
