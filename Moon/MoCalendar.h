//
//  MoCalendar.h
//
//
//  Created by Sanjay Madan on 11/13/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "MoDate.h"
#import "MoCalToolTipWC.h"

@protocol MoCalendarDelegate;

// =========================================================================
// MoCalendar
// =========================================================================

@interface MoCalendar : NSView

// The month this calendar displays.
// Only the month and year fields are used.
@property (nonatomic) MoDate monthDate;

// The selected date. Might be in monthDate or in
// the portion of the previous or next month that
// is shown in the calendar.
@property (nonatomic) MoDate selectedDate;

// Today's date.
@property (nonatomic) MoDate todayDate;

// The day of the week on which the week starts.
// 0...6; 0=Sunday, 1=Monday,... 6=Saturday
@property (nonatomic) NSInteger weekStartDOW;

// Is the week of the year column showing?
@property (nonatomic) BOOL showWeeks;

// Should the weekend by highlighted?
@property (nonatomic) BOOL highlightWeekend;

// An optional view controller for tooltips.
@property (nonatomic) NSViewController<MoCalTooltipProvider> *tooltipVC;

@property (nonatomic, weak) id<MoCalendarDelegate> delegate;

- (IBAction)showPreviousMonth:(id)sender;
- (IBAction)showNextMonth:(id)sender;
- (IBAction)showPreviousYear:(id)sender;
- (IBAction)showNextYear:(id)sender;
- (IBAction)showTodayMonth:(id)sender;
- (void)reloadData;
- (void)highlightCellsFromDate:(MoDate)startDate toDate:(MoDate)endDate withColor:(NSColor *)color;
- (void)unhighlightCells;

@end

// =========================================================================
// MoCalendarDelegate
// =========================================================================

@protocol MoCalendarDelegate <NSObject>

- (void)calendarUpdated:(MoCalendar *)cal;
- (void)calendarSelectionChanged:(MoCalendar *)cal;
- (BOOL)dateHasDot:(MoDate)date;

@end

