//
//  LunarCore.h
//  LunarCore
//
//  Created by cyan on 15/4/4.
//  Copyright (c) 2015年 cyan. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  获取指定年月的日历数据
 *
 *  @param _year  公历年
 *  @param _month 公历月
 *
 *  @return 该月日历
 */
NSMutableDictionary *calendar(int _year, int _month);

/**
 *  公历转换成农历
 *
 *  @param _year  公历年
 *  @param _month 公历月
 *  @param _month 公历日
 *
 *  @return 农历年月日
 */
NSMutableDictionary *solarToLunar(int _year, int _month, int _day);

/**
 *  农历转换成公历
 *
 *  @param _year  农历年
 *  @param _month 农历月
 *  @param _month 农历日
 *
 *  @return 公历年月日
 */
NSMutableDictionary *lunarToSolar(int _year, int _month, int _day);
