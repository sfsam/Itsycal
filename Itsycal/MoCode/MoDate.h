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
#define DOW_COL(startDOW, DOW) ((7 - startDOW + DOW) % 7)
// Reverse of DOW_COL. Get the DOW in a given COL.
#define COL_DOW(startDOW, COL) ((startDOW + COL) % 7)
#define IS_LEAP_YEAR(y)        ((y % 4) == 0 && ((y % 100) != 0 || (y % 400) == 0))
#define NO_JULIAN              (-1) // When Julian Day is undefined
#define MIN_MODATE_YEAR        (1583)
#define MAX_MODATE_YEAR        (3333)

/**
 * A Gregorian date.
 * We use a struct rather than a class because it has
 * copy (value vs reference) semantics and is easier to
 * reason about in use.
 */
typedef struct {
    NSInteger year;   // MIN_MODATE_YEAR...MAX_MODATE_YEAR
    NSInteger month;  // 0...11
    NSInteger day;    // 1...31
    NSInteger julian; // Julian Day
} MoDate;

/**
 * Make an NSString representing a date.
 * @param   date  The date.
 * @return  An NSString: "yyy-mm-dd (julian)".
 */
NSString *NSStringFromMoDate(MoDate date);

/**
 * Make a MoDate given year, month, and day.
 * @param   year   Year component of date.
 * @param   month  Month component of date.
 * @param   day    Day component of date.
 * @return  The date including the Julian Day.
 */
MoDate MakeDate(NSInteger year, NSInteger month, NSInteger day);

/**
 * Make a MoDate corresponding to the given NSDate and calendar.
 * @param   nsDate    The NSDate to be converted.
 * @param   calendar  The calendar used to interpret nsDate.
 * @return  A MoDate including the Julian Day.
 */
MoDate MakeDateWithNSDate(NSDate *nsDate, NSCalendar *calendar);

/**
 * Make an NSDate corresponding to the given MoDate and calendar.
 * @param   moDate    The MoDate to be converted.
 * @param   calendar  The calendar with which to create the resulting NSDate.
 * @return  An NSDate.
 */
NSDate *MakeNSDateWithDate(MoDate moDate, NSCalendar *calendar);

/**
 * The number of days in a month.
 * @param   year   The year.
 * @param   month  The month.
 * @return  The number of days in the given month.
 */
NSInteger DaysInMonth(NSInteger year, NSInteger month);

/**
 * Is a date valid?
 * @param   date  The date.
 * @return  YES if date is valid, else NO.
 */
BOOL IsValidDate(MoDate date);

/**
 * Compare two dates to see which is earlier.
 * @param   date1  The first date.
 * @param   date2  The second date.
 * @return  The difference in days between date1 and date2.
 *          The difference is
 *          < 0 if date1 is earlier;
 *          > 0 if date1 is later;
 *            0 if the dates are the same.
 */
NSInteger CompareDates(MoDate date1, MoDate date2);

/**
 * Get the number of ISO 8601 weeks in a year.
 * @param   year  The year.
 * @return  The number of ISO 8601 weeks in year.
 */
NSInteger WeeksInYear(NSInteger year);

/**
 * Get the ISO 8601 week number for a date.
 * @param   year    The year of the Gregorian date [1583+].
 * @param   month   The month of the Gregorian date [0..11].
 * @param   day     The day of the Gregorian date [1..31].
 * @return  The ISO 8601 week number for year-month-day.
 */
NSInteger WeekOfYear(NSInteger year, NSInteger month, NSInteger day);

/**
 * Make a Julian Day from a Gregorian date.
 * @param   year   The year of the Gregorian date [1583+].
 * @param   month  The month of the Gregorian date [0..11].
 * @param   day    The day of the Gregorian date [1..31].
 * @return  The Julian Day for year-month-day.
 */
NSInteger MakeJulian(NSInteger year, NSInteger month, NSInteger day);

/**
 * Make a Gregorian date from a Julian Day.
 * @param   julian  A Julian Day.
 * @return  The Gregorian date corresponding to julian.
 */
MoDate MakeGregorian(NSInteger julian);

/**
 * Add days to a Gregorian date to make a new date.
 * @param   days  The number of days to add.
 * @param   date  The date to which to add days.
 * @return  The date resulting from adding days to the
 *          Gregorian date.
 */
MoDate AddDaysToDate(NSInteger days, MoDate date);

/**
 * Add months to a month to make a new date.
 * @param   months  The number of months to add.
 * @param   date    The original year and month (day ignored).
 * @return  The month resulting from adding months to the
 *          input month. The day field of the resulting
 *          MoDate struct is 1.
 */
MoDate AddMonthsToMonth(NSInteger months, MoDate date);
