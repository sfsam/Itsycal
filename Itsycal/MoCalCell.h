//
//  MoCalCell.h
//
//
//  Created by Sanjay Madan on 12/3/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "MoDate.h"

#define kMoCalCellWidth  (23)
#define kMoCalCellHeight (23)

@interface MoCalCell : NSView

@property (nonatomic) NSTextField *textField;
@property (nonatomic) MoDate date;
@property (nonatomic) BOOL isToday;
@property (nonatomic) BOOL isHovered;
@property (nonatomic) BOOL isSelected;
@property (nonatomic) BOOL hasDot;

@end
