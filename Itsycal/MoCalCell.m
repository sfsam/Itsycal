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
    NSLayoutConstraint *_subTextFieldVerticalSpace;
    NSArray <NSLayoutConstraint*> *_subTextFieldHorizontalSpaces;
}

- (void)setupTextFiled
{
    _textField = [NSTextField labelWithString:@""];
    [_textField setFont:[NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightMedium]];
    [_textField setTextColor:[NSColor blackColor]];
    [_textField setAlignment:NSTextAlignmentCenter];
    [_textField setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:_textField];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_textField]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_textField)]];
    _textFieldVerticalSpace = [NSLayoutConstraint constraintWithItem:_textField attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:SizePref.cellTextFieldVerticalSpace];
    [self addConstraint:_textFieldVerticalSpace];
    
    REGISTER_FOR_SIZE_CHANGE;
    
}

- (void)setupSubtextFiled
{
    if(!_subTextField) {
        _subTextField = [NSTextField labelWithString:@""];
        [_subTextField setFont:[NSFont systemFontOfSize:SizePref.lunarDatefontSize weight:NSFontWeightLight]];
        [_subTextField setTextColor:[NSColor grayColor]];
        [_subTextField setAlignment:NSTextAlignmentCenter];
        [_subTextField setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:_subTextField];

        _subTextFieldHorizontalSpaces = [NSLayoutConstraint
                                         constraintsWithVisualFormat:@"H:|[_subTextField]|"
                                         options:0
                                         metrics:nil
                                         views:NSDictionaryOfVariableBindings(_subTextField)];
        _subTextFieldVerticalSpace = [NSLayoutConstraint constraintWithItem:_subTextField
                                                                  attribute:NSLayoutAttributeTop
                                                                  relatedBy:NSLayoutRelationEqual toItem:_textField
                                                                  attribute:NSLayoutAttributeBottom multiplier:1
                                                                   constant:SizePref.cellTextFieldVerticalSpace];
    }
    [self addConstraint:_subTextFieldVerticalSpace];
    [self addConstraints:_subTextFieldHorizontalSpaces];
}

- (void)removeSubTextField
{
    [self removeConstraint:_subTextFieldVerticalSpace];
    [self removeConstraints:_subTextFieldHorizontalSpaces];
}

- (instancetype)init
{
    CGSize sz = SizePref.cellSize;
    self = [super initWithFrame:NSMakeRect(0, 0, sz.width, sz.height)];
    if (self) {
        [self setupTextFiled];
        REGISTER_FOR_SIZE_CHANGE;
    }
    return self;
}

- (void)setDate:(MoDate)date
{
    _date = date;
}

- (void)sizeChanged:(id)sender
{
    [_textField setFont:[NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightMedium]];
    _textFieldVerticalSpace.constant = SizePref.cellTextFieldVerticalSpace;
    _subTextFieldVerticalSpace.constant = SizePref.cellTextFieldVerticalSpace;
    CGRect originFrame = self.frame;
    [self setFrame:CGRectMake(originFrame.origin.x, originFrame.origin.y, SizePref.cellSize.width, SizePref.cellSize.height)];
}

- (void)setIsToday:(BOOL)isToday {
    _isToday = isToday;
    [self setNeedsDisplay:YES];
}

- (void)setIsHighlighted:(BOOL)isHighlighted {
    _isHighlighted = isHighlighted;
    [self updateTextColor];
}

- (void)setIsInCurrentMonth:(BOOL)isInCurrentMonth {
    _isInCurrentMonth = isInCurrentMonth;
    [self updateTextColor];
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

- (void)setShowSubTitle:(BOOL)showSubTitle
{
    if(showSubTitle != _showSubTitle) {
        _showSubTitle = showSubTitle;
        showSubTitle ? [self setupSubtextFiled] : [self removeSubTextField] ;
        _subTextField.hidden = !showSubTitle;
        [self setNeedsLayout:YES];
    }
}

- (void)setDotColors:(NSArray<NSColor *> *)dotColors
{
    _dotColors = dotColors;
    [self setNeedsDisplay:YES];
}

- (void)updateTextColor {
    self.textField.textColor = self.isInCurrentMonth ? Theme.currentMonthTextColor : Theme.noncurrentMonthTextColor;
}

- (void)drawRect:(NSRect)dirtyRect
{
    CGFloat radius = SizePref.cellRadius;
    CGFloat borderWdith = SizePref.cellBorderWidth;
    if (self.isToday) {
        [Theme.todayCellColor set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
        [p setLineWidth:borderWdith];
        [p stroke];
    }
    else if (self.isSelected) {
        [Theme.selectedCellColor set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
        [p setLineWidth:borderWdith];
        [p stroke];
    }
    else if (self.isHovered) {
        [Theme.hoveredCellColor set];
        NSRect r = NSInsetRect(self.bounds, 3, 3);
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
        [p setLineWidth:borderWdith];
        [p stroke];
    }
    if (self.dotColors) {
        CGFloat cellWidth = SizePref.cellSize.width;
        CGFloat dotWidth = SizePref.cellDotWidth;
        CGFloat dotSpacing = 1.5*dotWidth;
        NSRect r = NSMakeRect(0, 0, dotWidth, dotWidth);
        r.origin.y = self.bounds.origin.y + dotWidth + borderWdith;
        if (self.dotColors.count == 0) {
            [self.textField.textColor set];
            r.origin.x = self.bounds.origin.x + cellWidth/2.0 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
        else if (self.dotColors.count == 1) {
            [self.dotColors[0] set];
            r.origin.x = self.bounds.origin.x + cellWidth/2.0 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
        else if (self.dotColors.count == 2) {
            [self.dotColors[0] set];
            r.origin.x = self.bounds.origin.x + cellWidth/2.0 - dotSpacing/2 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
            
            [self.dotColors[1] set];
            r.origin.x = self.bounds.origin.x + cellWidth/2.0 + dotSpacing/2 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
        else if (self.dotColors.count == 3) {
            [self.dotColors[0] set];
            r.origin.x = self.bounds.origin.x + cellWidth/2.0 - dotSpacing - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
            
            [self.dotColors[1] set];
            r.origin.x = self.bounds.origin.x + cellWidth/2.0 - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
            
            [self.dotColors[2] set];
            r.origin.x = self.bounds.origin.x + cellWidth/2.0 + dotSpacing - dotWidth/2.0;
            [[NSBezierPath bezierPathWithOvalInRect:r] fill];
        }
    }
}

@end
