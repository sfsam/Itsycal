//
//  LunarDate.m
//  Itsycal
//
//  Created by mx_in on 2022/7/20.
//  Copyright © 2022 mowglii.com. All rights reserved.
//

#import "LunarDate.h"
#import "LunarCore.h"


@implementation LunarDate

+ (instancetype)dateWithMoDate:(MoDate)moDate
{
    //the input month is [0...11], so the month needs to be added 1 for making a lunar date.
    NSDictionary *lunarDate = [solarToLunar((int)moDate.year, (int) moDate.month + 1, (int)moDate.day) copy];
    LunarDate *date = [[LunarDate alloc] initWithDictionary:lunarDate];
    return date;
}

- (id)initWithDictionary:(NSDictionary *)dic
{
    if(self = [super init]) {
        [self setValuesForKeysWithDictionary:dic];
    }
    return self;
}

@end
