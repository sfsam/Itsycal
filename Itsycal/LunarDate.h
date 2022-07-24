//
//  LunarDate.h
//  Itsycal
//
//  Created by mx_in on 2022/7/20.
//  Copyright © 2022 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MoDate.h"

NS_ASSUME_NONNULL_BEGIN

@interface LunarDate : NSObject

@property(nonatomic) NSString *GanZhiYear;
@property(nonatomic) NSInteger lunarDay;
@property(nonatomic) NSString *lunarDayName;
@property(nonatomic) NSString *lunarFestival;
@property(nonatomic) NSString *lunarMonthName;
@property(nonatomic) NSString *solarFestival;
@property(nonatomic) NSString *term;
@property(nonatomic) NSString *weekFestival;
@property(nonatomic) NSInteger worktime;
@property(nonatomic) NSString *zodiac;

+ (instancetype)dateWithMoDate:(MoDate)moDate;
- (instancetype)initWithDictionary:(NSDictionary *)dic;

@end

NS_ASSUME_NONNULL_END
