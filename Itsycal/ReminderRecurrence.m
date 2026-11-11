//
//  Created by Sanjay Madan on 10/24/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import "ReminderRecurrence.h"

// Stop after this many periods (days, weeks, months or years) even if
// rangeEnd hasn't been reached, e.g. for a rule that never matches.
static const NSInteger kMaxPeriods = 50000;

static const NSCalendarUnit kDayUnits = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday;

// The days from date for count days, each as year, month, day and
// weekday components. Days are computed at noon, so a daylight saving
// change can't move one to another day.
static NSArray<NSDateComponents *> *DaysFrom(NSCalendar *cal, NSDate *date, NSInteger count)
{
    NSDate *noon = [cal dateBySettingHour:12 minute:0 second:0 ofDate:date options:0];
    NSMutableArray *days = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        NSDate *day = [cal dateByAddingUnit:NSCalendarUnitDay value:i toDate:noon options:0];
        [days addObject:[cal components:kDayUnits fromDate:day]];
    }
    return days;
}

static NSDate *FirstOfMonth(NSCalendar *cal, NSInteger year, NSInteger month)
{
    NSDateComponents *c = [NSDateComponents new];
    c.year = year; c.month = month; c.day = 1; c.hour = 12;
    return [cal dateFromComponents:c];
}

static NSInteger DaysInMonth(NSCalendar *cal, NSInteger year, NSInteger month)
{
    return [cal rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:FirstOfMonth(cal, year, month)].length;
}

static NSArray<NSDateComponents *> *MonthDays(NSCalendar *cal, NSInteger year, NSInteger month)
{
    return DaysFrom(cal, FirstOfMonth(cal, year, month), DaysInMonth(cal, year, month));
}

static NSArray<NSDateComponents *> *YearDays(NSCalendar *cal, NSInteger year)
{
    NSMutableArray *days = [NSMutableArray new];
    for (NSInteger month = 1; month <= 12; month++) {
        [days addObjectsFromArray:MonthDays(cal, year, month)];
    }
    return days;
}

// Keep the days that match the rule's days of the month (negative ones
// count from the end of the month).
static NSArray<NSDateComponents *> *FilterDaysOfTheMonth(NSCalendar *cal, NSArray<NSDateComponents *> *days, NSArray<NSNumber *> *daysOfTheMonth)
{
    NSMutableArray *kept = [NSMutableArray new];
    for (NSDateComponents *d in days) {
        NSInteger length = DaysInMonth(cal, d.year, d.month);
        for (NSNumber *n in daysOfTheMonth) {
            NSInteger day = n.integerValue > 0 ? n.integerValue : length + 1 + n.integerValue;
            if (d.day == day) {
                [kept addObject:d];
                break;
            }
        }
    }
    return kept;
}

// Keep the days that match the rule's days of the week. A week number
// picks the nth such weekday in days (the month or year), counting
// from the end if negative. useWeekNumbers is NO for daily and weekly
// rules, where week numbers don't apply.
static NSArray<NSDateComponents *> *FilterDaysOfTheWeek(NSArray<NSDateComponents *> *days, NSArray<EKRecurrenceDayOfWeek *> *daysOfTheWeek, BOOL useWeekNumbers)
{
    NSMutableSet *kept = [NSMutableSet new];
    for (EKRecurrenceDayOfWeek *dow in daysOfTheWeek) {
        NSMutableArray *matching = [NSMutableArray new];
        for (NSDateComponents *d in days) {
            if (d.weekday == dow.dayOfTheWeek) [matching addObject:d];
        }
        NSInteger n = useWeekNumbers ? dow.weekNumber : 0;
        if (n == 0) {
            [kept addObjectsFromArray:matching];
        }
        else {
            NSInteger index = n > 0 ? n - 1 : (NSInteger)matching.count + n;
            if (index >= 0 && index < (NSInteger)matching.count) [kept addObject:matching[index]];
        }
    }
    // Back in day order.
    NSMutableArray *ordered = [NSMutableArray new];
    for (NSDateComponents *d in days) {
        if ([kept containsObject:d]) [ordered addObject:d];
    }
    return ordered;
}

static NSArray<NSDateComponents *> *FilterMonths(NSArray<NSDateComponents *> *days, NSArray<NSNumber *> *monthsOfTheYear)
{
    if (monthsOfTheYear.count == 0) return days;
    NSMutableArray *kept = [NSMutableArray new];
    for (NSDateComponents *d in days) {
        if ([monthsOfTheYear containsObject:@(d.month)]) [kept addObject:d];
    }
    return kept;
}

// Days in a month or year span by the rule's days of the month and
// week. With neither, the day of the month of start (and for a yearly
// rule without months, its month too).
static NSArray<NSDateComponents *> *SelectDays(NSCalendar *cal, NSArray<NSDateComponents *> *span, EKRecurrenceRule *rule, NSDateComponents *startDay, BOOL matchStartMonth)
{
    NSArray *days = span;
    if (rule.daysOfTheMonth.count) days = FilterDaysOfTheMonth(cal, days, rule.daysOfTheMonth);
    if (rule.daysOfTheWeek.count)  days = FilterDaysOfTheWeek(days, rule.daysOfTheWeek, YES);
    if (rule.daysOfTheMonth.count == 0 && rule.daysOfTheWeek.count == 0) {
        NSMutableArray *kept = [NSMutableArray new];
        for (NSDateComponents *d in days) {
            if (d.day == startDay.day && (!matchStartMonth || d.month == startDay.month)) [kept addObject:d];
        }
        days = kept;
    }
    return days;
}

// The days of one period: a day, a week, a month or a year.
static NSArray<NSDateComponents *> *PeriodDays(NSCalendar *cal, EKRecurrenceRule *rule, NSDate *periodStart, NSDateComponents *startDay)
{
    NSArray *days;
    switch (rule.frequency) {
        case EKRecurrenceFrequencyDaily:
            days = DaysFrom(cal, periodStart, 1);
            if (rule.daysOfTheMonth.count) days = FilterDaysOfTheMonth(cal, days, rule.daysOfTheMonth);
            if (rule.daysOfTheWeek.count)  days = FilterDaysOfTheWeek(days, rule.daysOfTheWeek, NO);
            return FilterMonths(days, rule.monthsOfTheYear);
        case EKRecurrenceFrequencyWeekly: {
            days = DaysFrom(cal, periodStart, 7);
            if (rule.daysOfTheWeek.count) {
                days = FilterDaysOfTheWeek(days, rule.daysOfTheWeek, NO);
            }
            else {
                NSMutableArray *kept = [NSMutableArray new];
                for (NSDateComponents *d in days) {
                    if (d.weekday == startDay.weekday) [kept addObject:d];
                }
                days = kept;
            }
            return FilterMonths(days, rule.monthsOfTheYear);
        }
        case EKRecurrenceFrequencyMonthly: {
            NSDateComponents *m = [cal components:kDayUnits fromDate:periodStart];
            days = SelectDays(cal, MonthDays(cal, m.year, m.month), rule, startDay, NO);
            return FilterMonths(days, rule.monthsOfTheYear);
        }
        case EKRecurrenceFrequencyYearly: {
            NSInteger year = [cal component:NSCalendarUnitYear fromDate:periodStart];
            if (rule.monthsOfTheYear.count) {
                // Week numbers count within each month.
                NSMutableArray *all = [NSMutableArray new];
                for (NSNumber *month in [rule.monthsOfTheYear sortedArrayUsingSelector:@selector(compare:)]) {
                    [all addObjectsFromArray:SelectDays(cal, MonthDays(cal, year, month.integerValue), rule, startDay, NO)];
                }
                return all;
            }
            // Week numbers count within the year.
            return SelectDays(cal, YearDays(cal, year), rule, startDay, YES);
        }
    }
    return @[];
}

// Pick the rule's set positions (1-based, or from the end if negative)
// from a period's days.
static NSArray<NSDateComponents *> *ApplySetPositions(NSArray<NSDateComponents *> *days, NSArray<NSNumber *> *setPositions)
{
    if (setPositions.count == 0) return days;
    NSMutableIndexSet *indexes = [NSMutableIndexSet new];
    for (NSNumber *p in setPositions) {
        NSInteger index = p.integerValue > 0 ? p.integerValue - 1 : (NSInteger)days.count + p.integerValue;
        if (index >= 0 && index < (NSInteger)days.count) [indexes addIndex:index];
    }
    return [days objectsAtIndexes:indexes];
}

NSArray<NSDate *> *RecurrenceDates(EKRecurrenceRule *rule, NSDate *start, NSCalendar *calendar, NSDate *rangeStart, NSDate *rangeEnd)
{
    if (rule.weeksOfTheYear.count || rule.daysOfTheYear.count) return nil;
    if (rule.interval < 1) return nil;

    NSCalendar *cal = calendar;
    NSDateComponents *startDay = [cal components:kDayUnits fromDate:start];
    NSDateComponents *startTime = [cal components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:start];
    NSInteger count = rule.recurrenceEnd.occurrenceCount; // 0 if none
    NSDate *until = rule.recurrenceEnd.endDate;

    // The start of the first period: start's day, the first day of its
    // week (Monday unless the rule says otherwise, as in RFC 5545), the
    // first of its month, or January 1 of its year.
    NSDate *startNoon = [cal dateBySettingHour:12 minute:0 second:0 ofDate:start options:0];
    NSDate *firstPeriod = startNoon;
    NSCalendarUnit periodUnit = NSCalendarUnitDay;
    NSInteger periodLength = 1;
    switch (rule.frequency) {
        case EKRecurrenceFrequencyDaily:
            break;
        case EKRecurrenceFrequencyWeekly: {
            NSInteger weekStart = rule.firstDayOfTheWeek ?: 2;
            NSInteger offset = (startDay.weekday - weekStart + 7) % 7;
            firstPeriod = [cal dateByAddingUnit:NSCalendarUnitDay value:-offset toDate:startNoon options:0];
            periodLength = 7;
            break;
        }
        case EKRecurrenceFrequencyMonthly:
            firstPeriod = FirstOfMonth(cal, startDay.year, startDay.month);
            periodUnit = NSCalendarUnitMonth;
            break;
        case EKRecurrenceFrequencyYearly:
            firstPeriod = FirstOfMonth(cal, startDay.year, 1);
            periodUnit = NSCalendarUnitYear;
            break;
    }

    NSMutableArray<NSDate *> *dates = [NSMutableArray new];
    NSInteger occurrences = 1; // start is the first occurrence
    for (NSInteger p = 0; p < kMaxPeriods; p++) {
        NSDate *periodStart = [cal dateByAddingUnit:periodUnit value:p * rule.interval * periodLength toDate:firstPeriod options:0];
        // Every day in this period is on or after its start, at noon.
        if ([[cal startOfDayForDate:periodStart] compare:rangeEnd] != NSOrderedAscending) break;
        NSArray *days = ApplySetPositions(PeriodDays(cal, rule, periodStart, startDay), rule.setPositions);
        for (NSDateComponents *d in days) {
            NSDateComponents *c = [NSDateComponents new];
            c.year = d.year; c.month = d.month; c.day = d.day;
            c.hour = startTime.hour; c.minute = startTime.minute; c.second = startTime.second;
            NSDate *date = [cal dateFromComponents:c];
            if (date == nil || [date compare:start] != NSOrderedDescending) continue;
            if (count > 0 && occurrences >= count) return dates;
            if (until && [date compare:until] == NSOrderedDescending) return dates;
            if ([date compare:rangeEnd] != NSOrderedAscending) return dates;
            occurrences++;
            if ([date compare:rangeStart] != NSOrderedAscending) [dates addObject:date];
        }
    }
    return dates;
}
