//
//  MoCalTooltipProvider.h
//  
//
//  Created by Sanjay Madan on 2/17/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MoDate.h"

@protocol MoCalTooltipProvider <NSObject>

- (void)toolTipForDate:(MoDate)date;

@end
