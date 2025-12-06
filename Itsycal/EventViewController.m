//
//  EventViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/25/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "EventViewController.h"
#import "EventCenter.h"
#import "MoVFLHelper.h"
#import "Themer.h"

@interface HackyTextView : NSTextView
// The placeholderAttributedString property in NSTextView
// isn't exposed publicly.
// https://stackoverflow.com/a/47223845/111418
@property NSAttributedString *placeholderAttributedString;
@end

@implementation HackyTextView
- (BOOL)becomeFirstResponder
{
    // Empty NSTextView gets focus but no cursor is visible
    // https://stackoverflow.com/a/39167917
    // https://stackoverflow.com/a/77020301/111418
    BOOL result = [super becomeFirstResponder];
    if (result) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.string.length) {
                self.string = @" ";
                self.string = @"";
            }
        });
    }
    return result;
}
@end

// These values map to _alertAllDayStrings and _alertRegularStrings.
enum {
    kAlertAllDayNumOffsets = 5,
    kAlertRegularNumOffsets = 10
};
const NSTimeInterval kAlertAllDayRelativeOffsets[kAlertAllDayNumOffsets] = {
    MAXFLOAT, // None
    32400,    // On day of event (9 AM)
    -54000,   // 1 day before (9 AM)
    -140400,  // 2 days before (9 AM)
    -572400   // 1 week before
};
const NSTimeInterval kAlertRegularRelativeOffsets[kAlertRegularNumOffsets] = {
    MAXFLOAT, // None
    0,        // At time of event
    -300,     // 5 minutes before
    -600,     // 10 minutes before
    -900,     // 15 minutes before
    -1800,    // 30 minutes before
    -3600,    // 1 hour before
    -7200,    // 2 hours before
    -86400,   // 1 day before
    -172800   // 2 days before
};

@implementation EventViewController
{
    NSTextField *_title, *_location, *_url, *_repEndLabel;
    NSButton *_allDayCheckbox, *_saveButton;
    NSDatePicker *_startDate, *_endDate, *_repEndDate;
    NSPopUpButton *_repPopup, *_repEndPopup, *_alertPopup, *_calPopup;
    NSArray<NSString *> *_alertAllDayStrings, *_alertRegularStrings;
    HackyTextView *_notes;
    NSScrollView *_notesScrollView;
    NSLayoutConstraint *_notesScrollViewHeightConstraint;
    CGFloat _notesHeightOfOneLine;
}

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];
    
    // TextField maker
    NSTextField* (^txt)(NSString*, BOOL) = ^NSTextField* (NSString *stringValue, BOOL isEditable) {
        NSTextField *txt;
        if (isEditable) {
            txt = [NSTextField textFieldWithString:@""];
            txt.placeholderString = stringValue;
            txt.bezeled = NO;
            txt.focusRingType = NSFocusRingTypeNone;
            txt.drawsBackground = NO;
        }
        else {
            txt = [NSTextField labelWithString:stringValue];
            txt.alignment = NSTextAlignmentRight;
        }
        [v addSubview:txt];
        return txt;
    };

    // DatePicker maker
    NSDatePicker* (^picker)(void) = ^NSDatePicker* () {
        NSDatePicker *picker = [NSDatePicker new];
        picker.datePickerStyle = NSDatePickerStyleTextField;
        picker.locale = NSLocale.currentLocale;
        picker.bezeled  = NO;
        picker.bordered = NO;
        picker.drawsBackground = NO;
        picker.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
        [v addSubview:picker];
        return picker;
    };

    // PopUpButton maker
    NSPopUpButton* (^popup)(SEL) = ^NSPopUpButton* (SEL action) {
        NSPopUpButton *pop = [NSPopUpButton new];
        pop.target = self;
        pop.action = action;
        pop.menu.autoenablesItems = NO;
        [v addSubview:pop];
        return pop;
    };
    
    // Button maker
    NSButton* (^btn)(NSString*, id, SEL) = ^NSButton* (NSString *title, id target, SEL action) {
        NSButton *btn = [NSButton buttonWithTitle:title target:target action:action];
        [v addSubview:btn];
        return btn;
    };

    // Title, location, and URL text fields
    _title = txt(NSLocalizedString(@"New Event", @""), YES);
    _title.delegate = self;
    _title.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
    _location = txt(NSLocalizedString(@"Add Location or Video Call", @""), YES);
    _url = txt(NSLocalizedString(@"Add URL", @""), YES);
    
    // All-day checkbox
    _allDayCheckbox = [NSButton new];
    _allDayCheckbox.title = @"";
    _allDayCheckbox.target = self;
    _allDayCheckbox.action = @selector(allDayClicked:);
    [_allDayCheckbox setButtonType:NSButtonTypeSwitch];
    [v addSubview:_allDayCheckbox];
    
    // Static labels
    NSTextField *allDayLabel = txt(NSLocalizedString(@"All-day:", @""), NO);
    NSTextField *startsLabel = txt(NSLocalizedString(@"Starts:", @""), NO);
    NSTextField *endsLabel   = txt(NSLocalizedString(@"Ends:", @""), NO);
    NSTextField *repLabel    = txt(NSLocalizedString(@"Repeat:", @""), NO);
                _repEndLabel = txt(NSLocalizedString(@"End Repeat:", @""), NO);
    NSTextField *alertLabel  = txt(NSLocalizedString(@"Alert:", @""), NO);
    
    // Date pickers
    _startDate = picker();
    _startDate.target = self;
    _startDate.action = @selector(startDateChanged:);
    _endDate    = picker();
    _repEndDate = picker();
    _repEndDate.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    
    // Popups
    _repPopup = popup(@selector(repPopupChanged:));
    [_repPopup addItemsWithTitles:@[NSLocalizedString(@"None", @"Repeat none"),
                                    NSLocalizedString(@"Every Day", @""),
                                    NSLocalizedString(@"Every Week", @""),
                                    [NSString stringWithFormat:NSLocalizedString(@"Every %zd Weeks", nil), (NSInteger)2],
                                    NSLocalizedString(@"Every Month", @""),
                                    NSLocalizedString(@"Every Year", @"")]];
    
    _repEndPopup = popup(@selector(repEndPopupChanged:));
    [_repEndPopup addItemsWithTitles:@[NSLocalizedString(@"Never", @"Repeat ends never"),
                                       NSLocalizedString(@"On Date", @"")]];
    
    _alertPopup = popup(NULL);
    _alertAllDayStrings = @[
        NSLocalizedString(@"None", @"Alert none"),
        NSLocalizedString(@"On day of event (9 AM)", @""),
        NSLocalizedString(@"1 day before (9 AM)", @""),
        NSLocalizedString(@"2 days before (9 AM)", @""),
        NSLocalizedString(@"1 week before", @"")];
    _alertRegularStrings = @[
        NSLocalizedString(@"None", @"Alert none"),
        NSLocalizedString(@"At time of event", @""),
        NSLocalizedString(@"5 minutes before", @""),
        NSLocalizedString(@"10 minutes before", @""),
        NSLocalizedString(@"15 minutes before", @""),
        NSLocalizedString(@"30 minutes before", @""),
        NSLocalizedString(@"1 hour before", @""),
        NSLocalizedString(@"2 hours before", @""),
        NSLocalizedString(@"1 day before", @""),
        NSLocalizedString(@"2 days before", @"")];
    // This is a hack.
    // Populate the alert with all possible values (there are
    // different values for regular vs. all-day events) so the
    // Autolayout engine can calculate the correct maximum
    // width of the button. The real values will be repopulated
    // in -viewWillAppear. Without this hack, the view may
    // change width when the user toggles between regular and
    // all-day events as the popup gets wider or narrower.
    [_alertPopup addItemsWithTitles:_alertAllDayStrings];
    [_alertPopup addItemsWithTitles:_alertRegularStrings];

    // Notes (NSTextView embedded in NSScrollView)
    _notesScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 100, 44)];
    _notesScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _notesScrollView.focusRingType = NSFocusRingTypeExterior;
    _notesScrollView.borderType = NSNoBorder;
    _notesScrollView.verticalScrollElasticity = NSScrollElasticityNone;
    _notesScrollView.drawsBackground = NO;
    _notesScrollView.hasVerticalScroller = YES;
    [v addSubview:_notesScrollView];

    NSSize noteContentSize = _notesScrollView.contentSize;
    _notes = [[HackyTextView alloc] initWithFrame:NSMakeRect(0, 0, noteContentSize.width, noteContentSize.height)];
    _notes.delegate = self;
    _notes.font = _location.font; // _title.font is too big
    _notes.placeholderAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Add Notes", @"") attributes:@{NSFontAttributeName: _notes.font, NSForegroundColorAttributeName: NSColor.disabledControlTextColor}];
    _notes.allowsUndo = YES;
    _notes.drawsBackground = NO;
    _notes.richText = NO;
    _notes.focusRingType = NSFocusRingTypeNone;
    _notes.minSize = NSMakeSize(0, noteContentSize.height);
    _notes.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    _notes.verticallyResizable = YES;
    _notes.horizontallyResizable = NO;
    _notes.autoresizingMask = NSViewWidthSizable;
    _notes.textContainer.widthTracksTextView = YES;
    [_notes.textContainer setLineFragmentPadding:0];
    [_notes.textContainer setContainerSize:NSMakeSize(noteContentSize.width, FLT_MAX)];

    _notesScrollView.documentView = _notes;

    _calPopup = popup(@selector(calPopupChanged:));
    _calPopup.imagePosition = NSImageOnly;
    
    // This is a hack.
    // Populate _calPopup with a dummy item so the Autolayout
    // engine can calculate its correct width. The real values
    // will be repopulated in -viewWillAppear.
    NSMenuItem *calItem = [NSMenuItem new];
    calItem.image = [NSImage imageWithSize:NSMakeSize(8, 8) flipped:NO drawingHandler:^BOOL(NSRect dstRect) { return YES; }];
    [_calPopup.menu addItem:calItem];
    
    // Save and Cancel buttons
    _saveButton = btn(NSLocalizedString(@"Save Event", @""), self, @selector(saveEvent:));
    _saveButton.enabled = NO; // we'll enable when the form is valid.
    NSButton *cancelButton = btn(NSLocalizedString(@"Cancel", @""), self, @selector(cancelOperation:));
    
    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:nil views:NSDictionaryOfVariableBindings(_title, _calPopup, _location, _allDayCheckbox, allDayLabel, startsLabel, endsLabel, _startDate, _endDate, repLabel, alertLabel, _repPopup, _repEndLabel, _repEndPopup, _repEndDate, _alertPopup, _notesScrollView, _url, cancelButton, _saveButton)];

    [vfl :@"V:|-[_title]-[_location]-15-[_allDayCheckbox]"];
    [vfl :@"V:[_allDayCheckbox]-[_startDate]-[_endDate]-[_repPopup]-[_repEndPopup]-[_alertPopup]" :NSLayoutFormatAlignAllLeading];
    [vfl :@"V:[_alertPopup]-20-[_notesScrollView]-10-[_url]-15-[_saveButton]-|"];
    [vfl :@"H:|-[_title]-[_calPopup]-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-[_location]-|"];
    [vfl :@"H:|-[allDayLabel]-[_allDayCheckbox]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[startsLabel]-[_startDate]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[endsLabel]-[_endDate]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[repLabel]-[_repPopup]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[_repEndLabel]-[_repEndPopup]-[_repEndDate]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[alertLabel]-[_alertPopup]-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-[_notesScrollView(>=200)]-|"];
    [vfl :@"H:|-[_url]-|"];
    [vfl :@"H:[cancelButton]-[_saveButton]-|" :NSLayoutFormatAlignAllCenterY];
    
    // Get height of one line in _notes
    [_notes.layoutManager ensureLayoutForTextContainer:_notes.textContainer];
    _notesHeightOfOneLine = [_notes.layoutManager usedRectForTextContainer:_notes.textContainer].size.height;

    // Set height of _notesScrollView to height of single line
    _notesScrollViewHeightConstraint = [_notesScrollView.heightAnchor constraintEqualToConstant:_notesHeightOfOneLine];
    _notesScrollViewHeightConstraint.active = YES;

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
    _url.stringValue = @"";
    _notes.string = @"";
    _allDayCheckbox.state = NSControlStateValueOff;
    _startDate.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
    _endDate.datePickerElements   = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
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
            [color set];
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
                // MacOS 13 sometimes returns nil for non-iCloud source titles.
                sourceItem.title   = calInfo.calendar.source.title ?: @"???";
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
    
    // Populate alert popup AFTER calendar popup since its
    // contents depends on which calendar is selected.
    [self populateAlertPopup];
}

- (void)viewDidAppear
{
    // Add a colored subview at the bottom the of popover's
    // window's frameView's view hierarchy. This should color
    // the popover including the arrow.
    NSView *frameView = self.view.window.contentView.superview;
    if (!frameView) return;
    if (frameView.subviews.count > 0
        && [frameView.subviews[0].identifier isEqualToString:@"popoverBackgroundBox"]) return;
    NSBox *backgroundColorView = [[NSBox alloc] initWithFrame:frameView.bounds];
    backgroundColorView.identifier = @"popoverBackgroundBox";
    backgroundColorView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    backgroundColorView.boxType = NSBoxCustom;
    backgroundColorView.borderWidth = 0;
    backgroundColorView.fillColor = Theme.mainBackgroundColor;
    [frameView addSubview:backgroundColorView positioned:NSWindowBelow relativeTo:nil];
}

- (void)cancelOperation:(id)sender
{
    // User hit 'esc' or pressed Cancel button.
    [self.enclosingPopover close];
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
    if (allDayCheckbox.state == NSControlStateValueOn) {
        _startDate.datePickerElements = NSDatePickerElementFlagYearMonthDay;
        _endDate.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    }
    else {
        _startDate.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
        _endDate.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
    }
    
    // All-day events have different alert options from regular events.
    [self populateAlertPopup];
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

- (void)calPopupChanged:(id)sender
{
    // Different calendars have different alert options.
    [self populateAlertPopup];
}

- (void)populateAlertPopup
{
    [_alertPopup removeAllItems];
    
    NSInteger numOffsets = 0;
    const NSTimeInterval *offsets = nil;

    if (_allDayCheckbox.state == NSControlStateValueOn) {
        [_alertPopup addItemsWithTitles:_alertAllDayStrings];
        numOffsets = kAlertAllDayNumOffsets;
        offsets = kAlertAllDayRelativeOffsets;
    } else {
        [_alertPopup addItemsWithTitles:_alertRegularStrings];
        numOffsets = kAlertRegularNumOffsets;
        offsets = kAlertRegularRelativeOffsets;
    }

    [_alertPopup selectItemAtIndex:0];

    // Get the selected calendar.
    NSInteger index = _calPopup.selectedItem.tag;
    NSArray *sourcesAndCalendars = [self.ec sourcesAndCalendars];
    CalendarInfo *calInfo = sourcesAndCalendars[index];

    // Make a dummy event for the selected calendar in order to get
    // the default alert time offset.
    EKEvent *dummyEvent  = [self.ec newEvent];
    dummyEvent.calendar  = calInfo.calendar;
    dummyEvent.allDay    = _allDayCheckbox.state == NSControlStateValueOn;

    // If the dummy event has an alert, try to set it as the default.
    if (dummyEvent.alarms.count > 0) {
        for (NSInteger i = 0; i < numOffsets; i++) {
            if (dummyEvent.alarms.firstObject.relativeOffset == offsets[i]) {
                [_alertPopup selectItemAtIndex:i];
                break;
            }
        }
    }
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
    EKEvent *event  = [self.ec newEvent];
    event.title     = [_title.stringValue stringByTrimmingCharactersInSet:whitespaceSet];
    event.location  = [_location.stringValue stringByTrimmingCharactersInSet:whitespaceSet];
    event.URL       = [NSURL URLWithString:[_url.stringValue stringByTrimmingCharactersInSet:whitespaceSet]];
    event.allDay    = _allDayCheckbox.state == NSControlStateValueOn;
    event.startDate = startDate;
    event.endDate   = endDate;
    event.calendar  = calInfo.calendar;
    NSString *notes = [_notes.string stringByTrimmingCharactersInSet:whitespaceSet];
    if (![notes isEqualToString:@""]) {
        event.notes = notes;
    }
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
    
    // Remove default alert(s) set on this event. We only add the
    // alert the user has selected - which may be the default alert
    // since we tried to set it in -populateAlertPopup. This avoids
    // having the default alert set twice.
    for (EKAlarm *alarm in event.alarms) {
        [event removeAlarm:alarm];
    }
    // Set the alert that was selected in the alert popup.
    NSInteger alertIndex = [_alertPopup indexOfItem:_alertPopup.selectedItem];
    if (alertIndex > 0) { // 0 == no alert
        NSTimeInterval offset = MAXFLOAT;
        if (event.isAllDay && alertIndex < kAlertAllDayNumOffsets) {
            offset = kAlertAllDayRelativeOffsets[alertIndex];
        }
        else if (!event.isAllDay && alertIndex < kAlertRegularNumOffsets) {
            offset = kAlertRegularRelativeOffsets[alertIndex];
        }
        if (offset != MAXFLOAT) {
            [event addAlarm:[EKAlarm alarmWithRelativeOffset:offset]];
        }
    }
    
    // Commit the event.
    NSError *error = NULL;
    BOOL saved = [self.ec saveEvent:event error:&error];
    if (saved == NO && error != nil) {
        [[NSAlert alertWithError:error] runModal];
    }
    else {
        [self.enclosingPopover close];
    }
}

#pragma mark -
#pragma mark NSTextViewDelegate

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
    // _notes textview handles Tab/Backtab like other controls
    // by navigating to next/previous control.
    // https://stackoverflow.com/a/2485987/111418
    if (aTextView != _notes) return NO;
    if (aSelector == @selector(insertTab:)) {
        [_notes.window makeFirstResponder:_url];
        return YES;
    }
    else if (aSelector == @selector(insertBacktab:)) {
        [_notes.window makeFirstResponder:_alertPopup];
        return YES;
    }
    return NO;
}

- (void)textDidChange:(NSNotification *)notification
{
    if (notification.object != _notes) return;

    // _notesScrollView will grow to at most this many lines
    // after which it will scroll.
    NSInteger maxVisibleLines = 16;

    // Get height of text in _notes
    [_notes.layoutManager ensureLayoutForTextContainer:_notes.textContainer];
    CGFloat height = [_notes.layoutManager usedRectForTextContainer:_notes.textContainer].size.height;
    
    // Grow _notesScrollView to at most maxVisibleLines * _notesHeightOfOneLine
    height = MIN(height, maxVisibleLines * _notesHeightOfOneLine);
    _notesScrollViewHeightConstraint.constant = height;
    
    // Get number of lines in _notes
    // https://macosx-dev.omnigroup.narkive.com/RH9lsO7P/number-of-lines-in-nstextview#post2
    NSInteger numberOfLines, idx, numberOfGlyphs = [_notes.layoutManager numberOfGlyphs];
    NSRange lineRange;
    for (numberOfLines = 0, idx = 0; idx < numberOfGlyphs; numberOfLines++) {
        (void)[_notes.layoutManager lineFragmentRectForGlyphAtIndex:idx effectiveRange:&lineRange];
        idx = NSMaxRange(lineRange);
    }
    
    // Disable elasticity if all lines are visible
    if (numberOfLines <= maxVisibleLines) {
        _notesScrollView.verticalScrollElasticity = NSScrollElasticityNone;
    }
    else {
        _notesScrollView.verticalScrollElasticity = NSScrollElasticityAutomatic;
    }
}

@end
