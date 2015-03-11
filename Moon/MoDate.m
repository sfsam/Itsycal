//
//  MoDate.m
//
//
//  Created by Sanjay Madan on 11/13/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoDate.h"

static const NSInteger kDaysInMonth[12] = {
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};

static const NSInteger kMonthDaysSoFar[12] = {
    0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
};

MoDate MakeDate(NSInteger year, NSInteger month, NSInteger day)
{
    MoDate date;
    date.year = year;
    date.month = month;
    date.day = day;
    date.julian = MakeJulian(year, month, day);
    return date;
}

MoDate MakeDateWithNSDate(NSDate *nsDate, NSCalendar *calendar)
{
    NSInteger year, month, day;
    [calendar getEra:NULL year:&year month:&month day:&day fromDate:nsDate];
    return MakeDate(year, month-1, day);
}

NSDate *MakeNSDateWithDate(MoDate moDate, NSCalendar *calendar)
{
    NSDate *nsDate = [calendar dateWithEra:1 year:moDate.year month:moDate.month+1 day:moDate.day hour:0 minute:0 second:0 nanosecond:0];
    return [calendar startOfDayForDate:nsDate];
}

BOOL IsValidDate(MoDate date)
{
    if  (date.year  < MIN_MODATE_YEAR ||
         date.year  > MAX_MODATE_YEAR ||
         date.month <  0 ||
         date.month > 11 ||
         date.day   <  1 ||
         date.day   > DaysInMonth(date.year, date.month)) {
        return NO;
    }
    return YES;
}

NSInteger CompareDates(MoDate date1, MoDate date2)
{
    // result < 0  => date1 is ealier
    // result > 0  => date1 is later
    // result = 0  => dates are the same
    NSInteger j1 = date1.julian == NO_JULIAN ? MakeJulian(date1.year, date1.month, date1.day) : date1.julian;
    NSInteger j2 = date2.julian == NO_JULIAN ? MakeJulian(date2.year, date2.month, date2.day) : date2.julian;
    return j1 - j2;
}

NSInteger DaysInMonth(NSInteger year, NSInteger month)
{
    return (month == 1 && IS_LEAP_YEAR(year)) ? 29 : kDaysInMonth[month];
}

NSInteger WeeksInYear(NSInteger year)
{
    // How many ISO 8601 weeks are there in a year?
    // A year has 53 weeks if it starts on Thursday -OR-
    // is a leap year and starts on Wednesday.
    // Otherwise, a year has 52 weeks.
    // en.wikipedia.org/wiki/ISO_week_date#Weeks_per_year
    
    // First, get the day of the week for January 1.
    // DOW algorithm by Michael Keith and Tom Craver
    // Result is [0..6]; 0=Sunday, 1=Monday...
    // stackoverflow.com/a/21235587/111418
    NSInteger y = year;
    NSInteger m = 1; // January
    NSInteger d = 1;
    NSInteger jan1DOW = (d+=m<3?y--:y-2,23*m/9+d+4+y/4-y/100+y/400)%7;
    
    // Is Jan1 a Thursday OR a Wednesday in a leap year?
    if (jan1DOW == 4 || (jan1DOW == 3 && IS_LEAP_YEAR(year))) {
        return 53;
    }
    return 52;
}

NSInteger WeekOfYear(NSInteger year, NSInteger month, NSInteger day)
{
    // First, calculate the day of the year.
    NSInteger dayOfYear = kMonthDaysSoFar[month] + day;
    if (month > 1 && IS_LEAP_YEAR(year)) {
        dayOfYear += 1;
    }
    // Next, calculate the week number.
    // en.wikipedia.org/wiki/ISO_week_date#Calculation
    NSInteger week = (dayOfYear + 9)/7;
    if (week > WeeksInYear(year)) {
        return 1;
    }
    else if (week < 1) {
        return WeeksInYear(year-1);
    }
    return week;
}

NSInteger MakeJulian(NSInteger year, NSInteger month, NSInteger day)
{
    // Algorithm 199
    // Conversions Between Calendar Date and Julian Day Number
    // Robert G. Tantzen
    // Air Force Missle Development Center, Holloman AFB, New Mexico
    // pmyers.pcug.org.au/IndexedMultipleYearCalendar/Calgo_199.PDF
    
    // Input month is [0..11], algorithm uses [1..12]
    month += 1;
    
    if (month > 2) {
        month -= 3;
    }
    else {
        month += 9;
        year -= 1;
    }
    NSInteger c = year/100;
    NSInteger ya = year - 100*c;
    return 146097*c/4 + 1461*ya/4 + (153*month + 2)/5 + day + 1721119;
}

MoDate MakeGregorian(NSInteger julian)
{
    // Algorithm 199
    // Conversions Between Calendar Date and Julian Day Number
    // Robert G. Tantzen
    // Air Force Missle Development Center, Holloman AFB, New Mexico
    // pmyers.pcug.org.au/IndexedMultipleYearCalendar/Calgo_199.PDF
    
    MoDate result;
    result.julian = julian;
    
    julian -= 1721119;
    NSInteger y = (4*julian - 1)/146097;
    julian = 4*julian - 1 - 146097*y;
    NSInteger d = julian/4;
    julian = (4*d + 3)/1461;
    d = 4*d + 3 - 1461*julian;
    d = (d + 4)/4;
    NSInteger m = (5*d - 3)/153;
    d = 5*d - 3 - 153*m;
    d = (d + 5)/5;
    y = 100*y + julian;
    if (m < 10) {
        m += 3;
    }
    else {
        m -= 9;
        y += 1;
    }
    
    // Algorithm uses months [1..12], CalDate uses [0..11]
    m -= 1;
    
    result.year  = y;
    result.month = m;
    result.day   = d;
    return result;
}

MoDate AddDaysToDate(NSInteger days, MoDate date)
{
    if (date.julian == NO_JULIAN) {
        date.julian = MakeJulian(date.year, date.month, date.day);
    }
    return MakeGregorian(date.julian + days);
}

MoDate AddMonthsToMonth(NSInteger months, MoDate date)
{
    NSInteger newYear  = date.year  + months/12;
    NSInteger newMonth = date.month + months%12;
    if (newMonth > 11) {
        newMonth -= 12;
        newYear  += 1;
    }
    else if (newMonth < 0) {
        newMonth += 12;
        newYear  -= 1;
    }
    return MakeDate(newYear, newMonth, 1);
}
