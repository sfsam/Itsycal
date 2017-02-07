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
#import "MoVFLHelper.h"

@implementation EventViewController
{
    NSTextField *_title, *_location, *_repEndLabel, *_alertLabel;
    NSButton *_allDayCheckbox, *_saveButton;
    NSDatePicker *_startDate, *_endDate, *_repEndDate;
    NSPopUpButton *_repPopup, *_repEndPopup, *_alertPopup, *_calPopup;
}

- (void)loadView
{
    // View controller content view
    MoView *v = [MoView new];
    
    // TextField maker
    NSTextField* (^txt)(NSString*, BOOL) = ^NSTextField* (NSString *stringValue, BOOL isEditable) {
        NSTextField *txt = [NSTextField new];
        txt.translatesAutoresizingMaskIntoConstraints = NO;
        txt.editable = isEditable;
        txt.bezeled = isEditable;
        txt.bezelStyle = NSTextFieldRoundedBezel;
        txt.drawsBackground = isEditable;
        if (isEditable) {
            txt.placeholderString = stringValue;
        }
        else {
            txt.stringValue = stringValue;
            txt.alignment = NSTextAlignmentRight;
            txt.textColor = [NSColor grayColor];
        }
        [v addSubview:txt];
        return txt;
    };

    // DatePicker maker
    NSDatePicker* (^picker)() = ^NSDatePicker* () {
        NSDatePicker *picker = [NSDatePicker new];
        picker.translatesAutoresizingMaskIntoConstraints = NO;
        picker.datePickerStyle = NSTextFieldDatePickerStyle;
        picker.bezeled  = NO;
        picker.bordered = NO;
        picker.drawsBackground = NO;
        picker.datePickerElements = NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag;
        [v addSubview:picker];
        return picker;
    };

    // PopUpButton maker
    NSPopUpButton* (^popup)() = ^NSPopUpButton* () {
        NSPopUpButton *pop = [NSPopUpButton new];
        pop.translatesAutoresizingMaskIntoConstraints = NO;
        pop.target = self;
        [v addSubview:pop];
        return pop;
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
    
    // Static labels
    NSTextField *allDayLabel = txt(NSLocalizedString(@"All-day:", @""), NO);
    NSTextField *startsLabel = txt(NSLocalizedString(@"Starts:", @""), NO);
    NSTextField *endsLabel   = txt(NSLocalizedString(@"Ends:", @""), NO);
    NSTextField *repLabel    = txt(NSLocalizedString(@"Repeat:", @""), NO);
    _repEndLabel             = txt(NSLocalizedString(@"End Repeat:", @""), NO);
    _alertLabel              = txt(NSLocalizedString(@"Alert:", @""), NO);
    
    // Date pickers
    _startDate = picker();
    _startDate.target = self;
    _startDate.action = @selector(startDateChanged:);
    _endDate    = picker();
    _repEndDate = picker();
    _repEndDate.datePickerElements = NSYearMonthDayDatePickerElementFlag;
    
    // Popups
    _repPopup = popup();
    _repPopup.action = @selector(repPopupChanged:);
    [_repPopup addItemsWithTitles:@[NSLocalizedString(@"None", @"Repeat none"),
                                    NSLocalizedString(@"Every Day", @""),
                                    NSLocalizedString(@"Every Week", @""),
                                    NSLocalizedString(@"Every 2 Weeks", @""),
                                    NSLocalizedString(@"Every Month", @""),
                                    NSLocalizedString(@"Every Year", @"")]];
    
    _repEndPopup = popup();
    _repEndPopup.action = @selector(repEndPopupChanged:);
    [_repEndPopup addItemsWithTitles:@[NSLocalizedString(@"Never", @"Repeat ends never"),
                                       NSLocalizedString(@"On Date", @"")]];
    
    _alertPopup = popup();
    [_alertPopup addItemsWithTitles:@[NSLocalizedString(@"None", @"Alert none"),
                                      NSLocalizedString(@"At time of event", @""),
                                      NSLocalizedString(@"5 minutes before", @""),
                                      NSLocalizedString(@"10 minutes before", @""),
                                      NSLocalizedString(@"15 minutes before", @""),
                                      NSLocalizedString(@"30 minutes before", @""),
                                      NSLocalizedString(@"1 hour before", @""),
                                      NSLocalizedString(@"2 hours before", @""),
                                      NSLocalizedString(@"1 day before", @""),
                                      NSLocalizedString(@"2 days before", @"")]];
    
    _calPopup = popup();
    _calPopup.menu.autoenablesItems = NO;
    
    // Save button
    _saveButton = [NSButton new];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveButton.bezelStyle = NSRoundedBezelStyle;
    _saveButton.title = NSLocalizedString(@"Save Event", @"");
    _saveButton.enabled = NO; // we'll enable when the form is valid.
    _saveButton.target = self;
    _saveButton.action = @selector(saveEvent:);
    [v addSubview:_saveButton];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:nil views:NSDictionaryOfVariableBindings(_title, _location, _allDayCheckbox, allDayLabel, startsLabel, endsLabel, _startDate, _endDate, repLabel, _alertLabel, _repPopup, _repEndLabel, _repEndPopup, _repEndDate, _alertPopup, _calPopup, _saveButton)];

    [vfl :@"V:|-[_title]-[_location]-15-[_allDayCheckbox]"];
    [vfl :@"V:[_allDayCheckbox]-[_startDate]-[_endDate]-[_repPopup]-[_repEndPopup]-20-[_alertPopup]-20-[_calPopup]" :NSLayoutFormatAlignAllLeading];
    [vfl :@"V:[_calPopup]-20-[_saveButton]-|"];
    [vfl :@"H:|-[_title(>=200)]-|"];
    [vfl :@"H:|-[_location]-|"];
    [vfl :@"H:|-[allDayLabel]-[_allDayCheckbox]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[startsLabel]-[_startDate]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[endsLabel]-[_endDate]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[repLabel]-[_repPopup]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[_repEndLabel]-[_repEndPopup]-[_repEndDate]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[_alertLabel]-[_alertPopup]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:[_calPopup]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:[_saveButton]-|"];
    
    // Require All-day checkbox height to hug the checkbox. Without this,
    // the layout will look funny when the title is multi-line.
    [_allDayCheckbox setContentHuggingPriority:999 forOrientation:NSLayoutConstraintOrientationVertical];
    
    // Pickers' width will change depending on state of _allDayCheckbox.
    // We don't want the size of the picker control to change (shrink)
    // when this happens so we set a very low hugging priority.
    [_startDate setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_endDate   setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    self.view.window.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
    self.view.window.defaultButtonCell = _saveButton.cell;
    
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
    _repEndLabel.hidden  = YES;
    _repEndPopup.hidden  = YES;
    _repEndDate.hidden   = YES;
    _repEndDate.minDate  = initialStart;
    _repEndDate.dateValue = initialEnd;
    [_repPopup selectItemAtIndex:0];     // 'None' selected
    [_repEndPopup selectItemAtIndex:0];  // 'Never' selected
    [_alertPopup selectItemAtIndex:0];   // 'None' selected
    _saveButton.enabled  = NO;
    
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
    EKSource *currentSource = nil;
    [_calPopup.menu removeAllItems];
    for (id obj in sourcesAndCalendars) {
        if ([obj isKindOfClass:[NSString class]]) continue; // Skip Sources
        CalendarInfo *calInfo = obj;
        // Only add menu items for calendars that can be modified.
        if (calInfo.calendar.allowsContentModifications) {
            // Add a Source item to the menu if necessary.
            if (![calInfo.calendar.source isEqualTo:currentSource]) {
                if (_calPopup.menu.itemArray.count != 0) {
                    [_calPopup.menu addItem:[NSMenuItem separatorItem]];
                }
                NSMenuItem *sourceItem = [NSMenuItem new];
                sourceItem.title   = calInfo.calendar.source.title;
                sourceItem.enabled = NO;
                [_calPopup.menu addItem:sourceItem];
                currentSource = calInfo.calendar.source;
            }
            NSMenuItem *calItem = [NSMenuItem new];
            calItem.title = calInfo.calendar.title;
            calItem.image = coloredDot(calInfo.calendar.color);
            calItem.tag   = [sourcesAndCalendars indexOfObject:obj];
            [_calPopup.menu addItem:calItem];
            if ([calInfo.calendar.calendarIdentifier isEqualToString:defaultCalendarIdentifier]) {
                [_calPopup selectItemWithTag:calItem.tag];
            }
        }
    }
    [self.view.window makeFirstResponder:_title];
}

- (void)cancel:(id)sender
{
    // User pressed 'esc'.
    [[self presentingViewController] dismissViewController:self];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    // Enable the Save button if the title is non-whitespace.
    NSString *trimmedTitle = [_title.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    _saveButton.enabled = ![trimmedTitle isEqualToString:@""];
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
    
    // The All-day checkbox also toggles the alert popup.
    // Currently, we don't allow the user to set an alert for an All-day event,
    // but a 1-day-ahead alert will be set by the system by default.
    if (allDayCheckbox.state == NSOnState) {
        _alertLabel.hidden = YES;
        _alertPopup.hidden = YES;
    }
    else {
        _alertLabel.hidden = NO;
        _alertPopup.hidden = NO;
    }
}

- (void)startDateChanged:(NSDatePicker *)startPicker
{
    // Make sure endDate is never before startDate.
    // Make sure repeatEndDate is never before endDate.
    // Default endDate is one hour after startDate.
    _endDate.minDate    = _startDate.dateValue;
    _repEndDate.minDate = _startDate.dateValue;
    _endDate.dateValue = [self.cal dateByAddingUnit:NSCalendarUnitHour value:1 toDate:_startDate.dateValue options:0];
}

- (void)repPopupChanged:(id)sender
{
    NSInteger repIndex = [_repPopup indexOfItem:_repPopup.selectedItem];
    NSInteger repEndIndex = [_repEndPopup indexOfItem:_repEndPopup.selectedItem];
    if (repIndex == 0) {
        [_repEndPopup selectItemAtIndex:0];
    }
    _repEndLabel.hidden = repIndex == 0;
    _repEndPopup.hidden = repIndex == 0;
    _repEndDate.hidden  = repIndex == 0 || repEndIndex == 0;
}

- (void)repEndPopupChanged:(id)sender
{
    NSInteger repEndIndex = [_repEndPopup indexOfItem:_repEndPopup.selectedItem];
    _repEndDate.hidden = repEndIndex == 0;
}

- (void)saveEvent:(id)sender
{
    // Set startDate and endDate.
    NSDate *startDate = _startDate.dateValue;
    NSDate *endDate   = _endDate.dateValue;
    
    // Get the calendar.
    NSInteger index = _calPopup.selectedItem.tag;
    NSArray *sourcesAndCalendars = [self.ec sourcesAndCalendars];
    CalendarInfo *calInfo = sourcesAndCalendars[index];

    // Create the event.
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    EKEvent *event  = [EKEvent eventWithEventStore:self.ec.store];
    event.title     = [_title.stringValue stringByTrimmingCharactersInSet:whitespaceSet];
    event.location  = [_location.stringValue stringByTrimmingCharactersInSet:whitespaceSet];
    event.allDay    = _allDayCheckbox.state == NSOnState;
    event.startDate = startDate;
    event.endDate   = endDate;
    event.calendar  = calInfo.calendar;
    // !Important! timeZone MUST be nil if it is an allDay event.
    // If you set timeZone after setting allDay, the start and end dates
    // will be wrong and it won't be an allDay event anymore.
    // Alternatively, we could have set timeZone before setting allDay
    // because setting allDay == YES sets timeZone to nil.
    event.timeZone  = event.isAllDay ? nil : [NSTimeZone localTimeZone];
    
    // Recurrence rule.
    EKRecurrenceFrequency frequency;
    NSInteger interval = 1;
    NSInteger repIndex = [_repPopup indexOfItem:_repPopup.selectedItem];
    switch (repIndex) {
        case 1: // Every Day
            frequency = EKRecurrenceFrequencyDaily;
            break;
        case 2: // Every Week
            frequency = EKRecurrenceFrequencyWeekly;
            break;
        case 3: // Every 2 Weeks
            frequency = EKRecurrenceFrequencyWeekly;
            interval  = 2;
            break;
        case 4: // Every Month
            frequency = EKRecurrenceFrequencyMonthly;
            break;
        case 5: // Every Year
            frequency = EKRecurrenceFrequencyYearly;
            break;
        default:
            frequency = EKRecurrenceFrequencyDaily;
            break;
    }
    EKRecurrenceEnd  *recurrenceEnd = nil;
    NSInteger repEndIndex = [_repEndPopup indexOfItem:_repEndPopup.selectedItem];
    if (repEndIndex != 0) {
        recurrenceEnd = [EKRecurrenceEnd recurrenceEndWithEndDate:_repEndDate.dateValue];
    }
    EKRecurrenceRule *recurrence = nil;
    if (repIndex != 0) {
        recurrence = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:frequency interval:interval end:recurrenceEnd];
    }
    if (recurrence != nil) {
        event.recurrenceRules = @[recurrence];
    }
    
    // Alert (aka Alarm).
    // Only set an alert if the event is NOT an All-day event. The system
    // will automatically set a 1-day-ahead alert for All-day events.
    if (event.allDay == NO) {
        NSInteger alertIndex = [_alertPopup indexOfItem:_alertPopup.selectedItem];
        if (alertIndex != 0) { // 0 == no alert
            NSTimeInterval offset = 0;
            switch (alertIndex) {
                case 2:  offset =    -300; break; //  5 min before
                case 3:  offset =    -600; break; // 10 min before
                case 4:  offset =    -900; break; // 15 min before
                case 5:  offset =   -1800; break; // 30 min before
                case 6:  offset =   -3600; break; //  1 hour before
                case 7:  offset =   -7200; break; //  2 hours before
                case 8:  offset =  -86400; break; //  1 day before
                case 9:  offset = -172800; break; //  2 days before
                default: offset =       0; break; // at time of event
            }
            [event addAlarm:[EKAlarm alarmWithRelativeOffset:offset]];
        }
    }
    
    // Commit the event.
    NSError *error = NULL;
    BOOL saved = [self.ec.store saveEvent:event span:EKSpanThisEvent commit:YES error:&error];
    if (saved == NO && error != nil) {
        [[NSAlert alertWithError:error] runModal];
    }
    else {
        [[self presentingViewController] dismissViewController:self];
    }
}

@end
