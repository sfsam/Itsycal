//
//  MoLunarCalculator.h
//  Itsycal
//
//  Created by Itsycal Agent on 12/9/25.
//  Copyright (c) 2025 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MoLunarDate : NSObject
@property (nonatomic) NSInteger day;
@property (nonatomic) NSInteger month;
@property (nonatomic) NSInteger year;
@property (nonatomic) BOOL isLeapMonth;

- (NSString *)description;
@end

@interface MoLunarCalculator : NSObject

+ (MoLunarDate *)solarToLunarWithDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year;
+ (MoLunarDate *)solarToLunar:(NSDate *)date;
+ (void)debugSolarToLunarWithDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year;

@end

NS_ASSUME_NONNULL_END
