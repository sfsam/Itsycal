//
//  EventViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/25/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "EventViewController.h"
#import "EventCenter.h"
#import "MoView.h"

@implementation EventViewController
{
    NSTextField *_title, *_location;
    NSButton *_allDayCheckbox, *_saveButton;
    NSDatePicker *_startDate, *_endDate;
    NSPopUpButton *_calPopup;
}

- (void)loadView
{
    // View controller content view
    MoView *v = [MoView new];
    v.backgroundColor = [NSColor colorWithWhite:0.92 alpha:1];
    v.viewIsOpaque = YES;
    v.translatesAutoresizingMaskIntoConstraints = NO;

    // Convenience function for making text fields.
    NSTextField* (^txt)(NSString*, BOOL) = ^NSTextField* (NSString *stringValue, BOOL isEditable) {
        NSTextField *txt = [NSTextField new];
        txt.font = [NSFont systemFontOfSize:12];
        txt.translatesAutoresizingMaskIntoConstraints = NO;
        txt.editable = isEditable;
        txt.bezeled = isEditable;
        txt.drawsBackground = isEditable;
        if (isEditable) {
            txt.placeholderString = stringValue;
        }
        else {
            txt.stringValue = stringValue;
            txt.alignment = NSRightTextAlignment;
            txt.textColor = [NSColor grayColor];
        }
        [v addSubview:txt];
        return txt;
    };

    // Title and location text fields
    _title = txt(NSLocalizedString(@"New Event", @""), YES);
    _title.delegate = self;
    _location = txt(NSLocalizedString(@"Add Location", @""), YES);
    
    // Login checkbox
    _allDayCheckbox = [NSButton new];
    _allDayCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    _allDayCheckbox.title = @"";
    _allDayCheckbox.target = self;
    _allDayCheckbox.action = @selector(allDayClicked:);
    [_allDayCheckbox setButtonType:NSSwitchButton];
    [v addSubview:_allDayCheckbox];
    
    // Labels
    NSTextField *allDayLabel = txt(NSLocalizedString(@"All-day:", @""), NO);
    NSTextField *startsLabel = txt(NSLocalizedString(@"Starts:", @""), NO);
    NSTextField *endsLabel   = txt(NSLocalizedString(@"Ends:", @""), NO);
    
    // Pickers
    NSDatePicker* (^picker)() = ^NSDatePicker* () {
        NSDatePicker *picker = [NSDatePicker new];
        picker.translatesAutoresizingMaskIntoConstraints = NO;
        picker.bezeled  = NO;
        picker.bordered = NO;
        picker.drawsBackground = NO;
        picker.datePickerElements = NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag;
        [v addSubview:picker];
        return picker;
    };
    _startDate = picker();
    _startDate.target = self;
    _startDate.action = @selector(startDateChanged:);
    _endDate   = picker();
    
    // Calendar popup
    _calPopup = [NSPopUpButton new];
    _calPopup.translatesAutoresizingMaskIntoConstraints = NO;
    _calPopup.menu.autoenablesItems = NO;
    [v addSubview:_calPopup];
    
    // Save button
    _saveButton = [NSButton new];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveButton.bezelStyle = NSRoundedBezelStyle;
    _saveButton.title = NSLocalizedString(@"Save Event", @"");
    _saveButton.keyEquivalent = @"\r"; // Make it the default button.
    _saveButton.enabled = NO; // we'll enable when the form is valid.
    _saveButton.target = self;
    _saveButton.action = @selector(saveEvent:);
    [v addSubview:_saveButton];

    // Convenience function to make visual constraints.
    void (^vcon)(NSString*, NSLayoutFormatOptions) = ^(NSString *format, NSLayoutFormatOptions opt) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:opt metrics:nil views:NSDictionaryOfVariableBindings(_title, _location, _allDayCheckbox, allDayLabel, startsLabel, endsLabel, _startDate, _endDate, _calPopup, _saveButton)]];
    };
    vcon(@"V:|-[_title]-[_location]-15-[_allDayCheckbox]", 0);
    vcon(@"V:[_allDayCheckbox]-[_startDate]-[_endDate]-[_calPopup]", NSLayoutFormatAlignAllLeading);
    vcon(@"V:[_calPopup]-[_saveButton]-|", 0);
    vcon(@"H:|-[_title(>=200)]-|", 0);
    vcon(@"H:|-[_location]-|", 0);
    vcon(@"H:|-[allDayLabel]-[_allDayCheckbox]-|", NSLayoutFormatAlignAllBaseline);
    vcon(@"H:|-[startsLabel]-[_startDate]-|", NSLayoutFormatAlignAllBaseline);
    vcon(@"H:|-[endsLabel]-[_endDate]-|", NSLayoutFormatAlignAllBaseline);
    vcon(@"H:[_calPopup]-|", NSLayoutFormatAlignAllBaseline);
    vcon(@"H:[_saveButton]-|", 0);
    
    // Pickers' will change depending on state of _allDayCheckbox.
    // We don't want the size of the picker control to change (shrink)
    // when this happens so we set a very low hugging priority.
    [_startDate setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_endDate   setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    
    // If self.calSelectedDate is today, the initialStart is set to
    // the next whole hour. Otherwise, 8am of self.calselectedDate.
    // InitialEnd is one hour after initialStart.
    NSDate *initialStart, *initialEnd, *today = [NSDate new];
    if ([self.cal isDate:self.calSelectedDate inSameDayAsDate:today]) {
        NSInteger hour;
        [self.cal getHour:&hour minute:NULL second:NULL nanosecond:NULL fromDate:today];
        hour = (hour == 23) ? 0 : hour+1;
        initialStart = [self.cal nextDateAfterDate:today matchingUnit:NSCalendarUnitHour value:hour options:NSCalendarMatchNextTimePreservingSmallerUnits];
    }
    else {
        initialStart = [self.cal dateBySettingHour:8 minute:0 second:0 ofDate:self.calSelectedDate options:0];
    }
    initialEnd = [self.cal dateByAddingUnit:NSCalendarUnitHour value:1 toDate:initialStart options:0];
    
    // Initial values for form fields.
    _title.stringValue = @"";
    _location.stringValue = @"";
    _allDayCheckbox.state = NSOffState;
    _startDate.datePickerElements = NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag;
    _endDate.datePickerElements   = NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag;
    _startDate.dateValue = initialStart;
    _endDate.minDate     = initialStart; // !! Must set minDate before dateValue !!
    _endDate.dateValue   = initialEnd;
    
    // Function to make colored dots for calendar popup.
    NSImage* (^coloredDot)(NSColor *) = ^NSImage* (NSColor *color) {
        return [NSImage imageWithSize:NSMakeSize(8, 8) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            [[color blendedColorWithFraction:0.3 ofColor:[NSColor whiteColor]] set];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, 0, 8, 8)] fill];
            return YES;
        }];
    };
    
    // Populate calendar popup.
    NSString *defaultCalendarIdentifier = [self.ec defaultCalendarIdentifier];
    NSArray *sourcesAndCalendars = [self.ec sourcesAndCalendars];
    [_calPopup.menu removeAllItems];
    for (id obj in sourcesAndCalendars) {
        NSMenuItem *item = [NSMenuItem new];
        // Add item for Source
        if ([obj isKindOfClass:[NSString class]]) {
            if (_calPopup.menu.itemArray.count != 0) {
                [_calPopup.menu addItem:[NSMenuItem separatorItem]];
            }
            item.title = obj;
            item.enabled = NO;
            [_calPopup.menu addItem:item];
        }
        // Add item for Calendar if calendar can be modified
        else {
            CalendarInfo *info = obj;
            if (info.calendar.allowsContentModifications) {
                item.title = info.calendar.title;
                item.image = coloredDot(info.calendar.color);
                item.tag = [sourcesAndCalendars indexOfObject:obj];
                [_calPopup.menu addItem:item];
                if ([info.calendar.calendarIdentifier isEqualToString:defaultCalendarIdentifier]) {
                    [_calPopup selectItemWithTag:item.tag];
                }
            }
        }
    }
    [self.view.window makeFirstResponder:_title];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    _saveButton.enabled = ![_title.stringValue isEqualToString:@""];
}

- (void)allDayClicked:(NSButton *)allDayCheckbox
{
    // The All-day checkbox toggles the hour/minute controls of the date pickers.
    if (allDayCheckbox.state == NSOnState) {
        _startDate.datePickerElements = NSYearMonthDayDatePickerElementFlag;
        _endDate.datePickerElements = NSYearMonthDayDatePickerElementFlag;
    }
    else {
        _startDate.datePickerElements = NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag;
        _endDate.datePickerElements = NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag;
    }
}

- (void)startDateChanged:(NSDatePicker *)startPicker
{
    // Make sure endDate is never before startDate.
    // Default endDate is one hour after startDate.
    _endDate.minDate = _startDate.dateValue;
    _endDate.dateValue = [self.cal dateByAddingUnit:NSCalendarUnitHour value:1 toDate:_startDate.dateValue options:0];
}

- (void)saveEvent:(id)sender
{
    // Set startDate and endDate.
    NSDate *startDate = _startDate.dateValue;
    NSDate *endDate   = _endDate.dateValue;
    if (_allDayCheckbox.state == NSOnState) {
        startDate = [self.cal startOfDayForDate:_startDate.dateValue];
        endDate   = [self.cal dateByAddingUnit:NSCalendarUnitDay value:1 toDate:endDate options:0];
        endDate   = [self.cal startOfDayForDate:endDate];
    }

    // Get the calendar.
    NSInteger index = _calPopup.selectedItem.tag;
    NSArray *sourcesAndCalendars = [self.ec sourcesAndCalendars];
    CalendarInfo *calInfo = sourcesAndCalendars[index];

    // Create the event.
    EKEvent *event  = [EKEvent eventWithEventStore:self.ec.store];
    event.title     = _title.stringValue;
    event.location  = _location.stringValue;
    event.allDay    = _allDayCheckbox.state == NSOnState;
    event.startDate = startDate;
    event.endDate   = endDate;
    event.calendar  = calInfo.calendar;
    
    // Commit the event.
    NSError *error = NULL;
    if ([self.ec.store saveEvent:event span:EKSpanThisEvent commit:YES error:&error]) {
        [self.view.window.windowController close];
    }
    else {
        [[NSAlert alertWithError:error] runModal];
    }
}

@end
