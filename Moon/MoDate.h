//
//  MoDate.h
//
//
//  Created by Sanjay Madan on 11/13/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>

//
// A monthly calendar has seven columns, one for each day.
// Given the day on which a week starts, in which column
// is a particular day? Day codes: 0=Sunday,...6=Saturday
//
// Example:
// If weeks start on Monday, what column is Saturday?
// DOW_COL(1, 6) = (7 - 1 + 6)%7 = 12%7 = 5
//
//  0  1  2  3  4  5  6  <=Column
// Mo Tu We Th Fr Sa Su  <=DayOfWeek
//                ^^
#define DOW_COL(startDOW, DOW) ((7 - startDOW + DOW)%7)
#define IS_LEAP_YEAR(y)        ((y % 4) == 0 && ((y % 100) != 0 || (y % 400) == 0))
#define NO_JULIAN              (-1) // When Julian Day is undefined
#define MIN_MODATE_YEAR        (1583)
#define MAX_MODATE_YEAR        (3333)
typedef struct {
    NSInteger year;   // MIN_MODATE_YEAR...MAX_MODATE_YEAR
    NSInteger month;  // 0...11
    NSInteger day;    // 1...31
    NSInteger julian; // Julian Day
} MoDate;

typedef struct {
    NSInteger year;     // MIN_MODATE_YEAR...MAX_MODATE_YEAR
    NSInteger month;    // 0...11
    NSInteger weeks[6]; // 1...53 ISO 8601 weeks
    MoDate dates[6][7];
} MoMonth;

//
// Make a date
// year, month day  the components of the date
// return           a date including julian day
//
MoDate MakeDate(NSInteger year, NSInteger month, NSInteger day);

//
// Make a date
// nsDate    the date as an NSDate
// calendar  the calendar to use to interpret nsDate
// return    a date including julian day
//
MoDate MakeDateWithNSDate(NSDate *nsDate, NSCalendar *calendar);

//
// Make an NSDate
// moDate    the date as a MoDate
// calendar  the calendar with which to create the resulting NSDate
// return    an NSDate
//
NSDate *MakeNSDateWithDate(MoDate moDate, NSCalendar *calendar);

//
// The number of days in a month
// year, month  the year and month
// return       the number of days in that month
//
NSInteger DaysInMonth(NSInteger year, NSInteger month);

//
// Is a date valid?
// date    the date
// return  1 if date is valid, else 0
//
NSInteger IsValidDate(MoDate date);

//
// Is a date valid?
// y, m, d  the year, month, day
// return   1 if y-m-d is valid, else 0
//
NSInteger IsValidDate2(NSInteger y, NSInteger m, NSInteger d);

//
// Compare two dates
// date1    the first date
// date2    the second date
// return  -1 if the first date is earlier,
//          1 if the first date is later,
//          0 if the dates are the same
//
NSInteger CompareDates(MoDate date1, MoDate date2);

//
// Compare two dates
// y1, m1, d1  the year, month, day of the first date
// y2, m2, d2  the year, month, day of the second date
// return      -1 if the first date is earlier,
//              1 if the first date is later,
//              0 if the dates are the same
//
NSInteger CompareDates2(NSInteger y1, NSInteger m1, NSInteger d1, NSInteger y2, NSInteger m2, NSInteger d2);

//
// Get the number of ISO 8601 weeks in a year
// year    the year
// return  the number of ISO 8601 weeks in year
//
NSInteger WeeksInYear(NSInteger year);

//
// Get the ISO 8601 week number for a date
// year    the year of the Gregorian date [1583+]
// month   the month of the Gregorian date [0..11]
// day     the day of the Gregorian date [1..31]
// return  the ISO 8601 week # for year-month-day
//
NSInteger WeekOfYear(NSInteger year, NSInteger month, NSInteger day);

//
// Convert a Gregorian date to a Julian Day
// year    the year of the Gregorian date [1583+]
// month   the month of the Gregorian date [0..11]
// day     the day of the Gregorian date [1..31]
// return  the Julian Day for year-month-day
//
NSInteger MakeJulian(NSInteger year, NSInteger month, NSInteger day);

//
// Convert a Julian Day to a Gregorian date
// julian  a Julian Day
// return  the Gregorian date for julian
//
MoDate MakeGregorian(NSInteger julian);

//
// Add days to a Gregorian date to make a new date
// days    the number of days to add
// date    the date to which to add days
// return  the date resulting from adding days to the
//         Gregorian date
//
MoDate AddDaysToDate(NSInteger days, MoDate date);

//
// Add months to a month to make a new date
// months  the number of months to add
// date    the original year and month (day ignored)
// return  the month resulting from adding months to the
//         input month; the day field of the resulting
//         MoDate struct is 1
//
MoDate AddMonthsToMonth(NSInteger months, MoDate date);

//
// Make a monthly calendar for a particular month
// year          the year of the date [1583+]
// month         the month of the date [0..11]
// weekStartDOW  the day of the week on which the week
//               starts [0..6]; 0=Sunday, 1=Monday...
// return        the monthly calendar
//
MoMonth MakeMonth(NSInteger year, NSInteger month, NSInteger weekStartDOW);
