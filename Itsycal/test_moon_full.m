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
//
//  MoLunarCalculator.m
//  Itsycal
//
//  Created by Itsycal Agent on 12/9/25.
//  Copyright (c) 2025 mowglii.com. All rights reserved.
//

#import "MoLunarCalculator.h"

@implementation MoLunarDate
- (NSString *)description {
    return [NSString stringWithFormat:@"%ld/%ld/%ld%@", (long)_day, (long)_month, (long)_year, _isLeapMonth ? @" (Leap)" : @""];
}
@end

@implementation MoLunarCalculator

static const double PI = M_PI;
static const double TIMEZONE = 7.0;

#pragma mark - Helper Functions

static NSInteger INT(double d) {
    return (NSInteger)floor(d);
}

// Compute the (integral) Julian day number of day dd/mm/yyyy
static NSInteger jdFromDate(NSInteger dd, NSInteger mm, NSInteger yy) {
    NSInteger a, y, m, jd;
    a = INT((14 - mm) / 12.0);
    y = yy + 4800 - a;
    m = mm + 12 * a - 3;
    jd = dd + INT((153 * m + 2) / 5.0) + 365 * y + INT(y / 4.0) - INT(y / 100.0) + INT(y / 400.0) - 32045;
    if (jd < 2299161) {
        jd = dd + INT((153 * m + 2) / 5.0) + 365 * y + INT(y / 4.0) - 32083;
    }
    return jd;
}

// Compute the time of the k-th new moon after the new moon of 1/1/1900 13:52 UTC
static double NewMoon(double k) {
    double T, T2, T3, dr, Jd1, M, Mpr, F, C1, deltat, JdNew;
    T = k / 1236.85; // Time in Julian centuries from 1900 January 0.5
    T2 = T * T;
    T3 = T2 * T;
    dr = PI / 180.0;
    Jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3;
    Jd1 = Jd1 + 0.00033 * sin((166.56 + 132.87 * T - 0.009173 * T2) * dr); // Mean new moon
    M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3; // Sun's mean anomaly
    Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3; // Moon's mean anomaly
    F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3; // Moon's argument of latitude
    C1 = (0.1734 - 0.000393 * T) * sin(M * dr) + 0.0021 * sin(2 * dr * M);
    C1 = C1 - 0.4068 * sin(Mpr * dr) + 0.0161 * sin(dr * 2 * Mpr);
    C1 = C1 - 0.0004 * sin(dr * 3 * Mpr);
    C1 = C1 + 0.0104 * sin(dr * 2 * F) - 0.0051 * sin(dr * (M + Mpr));
    C1 = C1 - 0.0074 * sin(dr * (M - Mpr)) + 0.0004 * sin(dr * (2 * F + M));
    C1 = C1 - 0.0004 * sin(dr * (2 * F - M)) - 0.0006 * sin(dr * (2 * F + Mpr));
    C1 = C1 + 0.0010 * sin(dr * (2 * F - Mpr)) + 0.0005 * sin(dr * (2 * Mpr + M));
    if (T < -11) {
        deltat = 0.001 + 0.000839 * T + 0.0002261 * T2 - 0.00000845 * T3 - 0.000000081 * T * T3;
    } else {
        deltat = -0.000278 + 0.000265 * T + 0.000262 * T2;
    }
    JdNew = Jd1 + C1 - deltat;
    return JdNew;
}

// Compute the longitude of the sun at any time
static double SunLongitude(double jdn) {
    double T, T2, dr, M, L0, DL, L;
    T = (jdn - 2451545.0) / 36525.0; // Time in Julian centuries from 2000-01-01 12:00:00 GMT
    T2 = T * T;
    dr = PI / 180.0; // degree to radian
    M = 357.52910 + 35999.05030 * T - 0.0001559 * T2 - 0.00000048 * T * T2; // mean anomaly, degree
    L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2; // mean longitude, degree
    DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * sin(dr * M);
    DL = DL + (0.019993 - 0.000101 * T) * sin(dr * 2 * M) + 0.000290 * sin(dr * 3 * M);
    L = L0 + DL; // true longitude, degree
    L = L * dr;
    L = L - PI * 2 * (INT(L / (PI * 2))); // Normalize to (0, 2*PI)
    return L;
}

static NSInteger getSunLongitude(double dayNumber, double timeZone) {
    return INT(SunLongitude(dayNumber - 0.5 - timeZone / 24.0) / PI * 6);
}

static NSInteger getNewMoonDay(double k, double timeZone) {
    return INT(NewMoon(k) + 0.5 + timeZone / 24.0);
}

static NSInteger getLunarMonth11(NSInteger yy, double timeZone) {
    double k, off;
    NSInteger nm, sunLong;
    off = jdFromDate(31, 12, yy) - 2415021;
    k = INT(off / 29.530588853);
    nm = getNewMoonDay(k, timeZone);
    sunLong = getSunLongitude(nm, timeZone); // sun longitude at local midnight
    if (sunLong >= 9) {
        nm = getNewMoonDay(k - 1, timeZone);
    }
    return nm;
}

static NSInteger getLeapMonthOffset(NSInteger a11, double timeZone) {
    double k;
    NSInteger last, arc, i;
    k = INT((a11 - 2415021.076998695) / 29.530588853 + 0.5);
    last = 0;
    i = 1; // We start with the month following lunar month 11
    arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
    do {
        last = arc;
        i++;
        arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
    } while (arc != last && i < 14);
    return i - 1;
}

+ (MoLunarDate *)solarToLunarWithDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year {
    // Port of convertSolar2Lunar
    double k;
    NSInteger dayNumber, monthStart, a11, b11, lunarDay, lunarMonth;
    NSInteger lunarYear, lunarLeap, diff, leapMonthDiff;
    
    dayNumber = jdFromDate(day, month, year);
    k = INT((dayNumber - 2415021.076998695) / 29.530588853);
    monthStart = getNewMoonDay(k + 1, TIMEZONE);
    if (monthStart > dayNumber) {
        monthStart = getNewMoonDay(k, TIMEZONE);
    }
    
    a11 = getLunarMonth11(year, TIMEZONE);
    b11 = a11;
    
    if (a11 >= monthStart) {
        lunarYear = year;
        a11 = getLunarMonth11(year - 1, TIMEZONE);
    } else {
        lunarYear = year + 1;
        b11 = getLunarMonth11(year + 1, TIMEZONE);
    }
    
    lunarDay = dayNumber - monthStart + 1;
    diff = INT((monthStart - a11) / 29.0);
    lunarLeap = 0;
    lunarMonth = diff + 11;
    
    if (b11 - a11 > 365) {
        leapMonthDiff = getLeapMonthOffset(a11, TIMEZONE);
        if (diff >= leapMonthDiff) {
            lunarMonth = diff + 10;
            if (diff == leapMonthDiff) {
                lunarLeap = 1;
            }
        }
    }
    
    if (lunarMonth > 12) {
        lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
        lunarYear -= 1;
    }
    
    MoLunarDate *date = [MoLunarDate new];
    date.day = lunarDay;
    date.month = lunarMonth;
    date.year = lunarYear;
    date.isLeapMonth = (lunarLeap == 1);
    
    return date;
}

+ (void)debugSolarToLunarWithDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year {
    double k;
    NSInteger dayNumber, monthStart, a11, b11, lunarDay, lunarMonth;
    NSInteger lunarYear, lunarLeap, diff, leapMonthDiff;
    
    dayNumber = jdFromDate(day, month, year);
    k = INT((dayNumber - 2415021.076998695) / 29.530588853);
    monthStart = getNewMoonDay(k + 1, TIMEZONE);
    if (monthStart > dayNumber) {
        monthStart = getNewMoonDay(k, TIMEZONE);
    }
    
    a11 = getLunarMonth11(year, TIMEZONE);
    b11 = a11;
    
    if (a11 >= monthStart) {
        lunarYear = year;
        a11 = getLunarMonth11(year - 1, TIMEZONE);
    } else {
        lunarYear = year + 1;
        b11 = getLunarMonth11(year + 1, TIMEZONE);
    }
    
    lunarDay = dayNumber - monthStart + 1;
    diff = INT((monthStart - a11) / 29.0);
    lunarLeap = 0;
    lunarMonth = diff + 11;
    
    NSLog(@"DEBUG LUNAR: Date: %ld/%ld/%ld", (long)day, (long)month, (long)year);
    NSLog(@"DEBUG LUNAR: dayNumber: %ld", (long)dayNumber);
    NSLog(@"DEBUG LUNAR: monthStart: %ld", (long)monthStart);
    NSLog(@"DEBUG LUNAR: a11: %ld", (long)a11);
    NSLog(@"DEBUG LUNAR: b11: %ld", (long)b11);
    NSLog(@"DEBUG LUNAR: diff: %ld", (long)diff);
    
    if (b11 - a11 > 365) {
        leapMonthDiff = getLeapMonthOffset(a11, TIMEZONE);
        NSLog(@"DEBUG LUNAR: Leap Month detected. leapMonthDiff: %ld", (long)leapMonthDiff);
        if (diff >= leapMonthDiff) {
            lunarMonth = diff + 10;
            if (diff == leapMonthDiff) {
                lunarLeap = 1;
            }
        }
    } else {
        NSLog(@"DEBUG LUNAR: No Leap Month");
    }
    
    if (lunarMonth > 12) {
        lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
        lunarYear -= 1;
    }
    
    NSLog(@"DEBUG LUNAR: Result: %ld/%ld/%ld (Leap: %d)", (long)lunarDay, (long)lunarMonth, (long)lunarYear, lunarLeap);
}

+ (MoLunarDate *)solarToLunar:(NSDate *)date {
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:date];
    return [self solarToLunarWithDay:comps.day month:comps.month year:comps.year];
}

@end
