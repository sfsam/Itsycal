//
//  Created by Sanjay Madan on 1/9/24.
//  Copyright © 2024 mowglii.com. All rights reserved.
//

#import "DatePickerVC.h"
#import "MoThemeView.h"
#import "MoVFLHelper.h"

@implementation DatePickerVC
{
    NSDatePicker *_picker;
    __weak MoCalendar *_moCal;
    __weak NSCalendar *_nsCal;
}

- (instancetype)initWithMoCal:(MoCalendar *)moCal nsCal:(NSCalendar *)nsCal
{
    self = [super init];
    if (self) {
        _moCal = moCal;
        _nsCal = nsCal;
    }
    return self;
}

- (void)loadView
{
    NSView *v = [NSView new];

    _picker = [NSDatePicker new];
    _picker.datePickerStyle = NSDatePickerStyleTextField;
    _picker.locale = NSLocale.currentLocale;
    _picker.bezeled  = YES;
    _picker.bordered = NO;
    _picker.drawsBackground = NO;
    _picker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    _picker.dateValue = MakeNSDateWithDate(_moCal.selectedDate, _nsCal);
    [v addSubview:_picker];

    NSTextField *label = [NSTextField labelWithString:NSLocalizedString(@"Go to date", @"")];
    label.font = [NSFont systemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightSemibold];
    [v addSubview:label];

    NSButton *btn = [NSButton buttonWithTitle:@"→" target:self action:@selector(buttonAction:)];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.keyEquivalent = @"\r";
    [v addSubview:btn];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:nil views:NSDictionaryOfVariableBindings(_picker, label, btn)];
    [vfl :@"H:|-10-[_picker]-[btn]-10-|" :NSLayoutFormatAlignAllLastBaseline];
    [vfl :@"V:|-10-[label]-[_picker]-10-|" :NSLayoutFormatAlignAllLeading];

    // The popover has hasFullSizeContent=YES. Use the
    // safeAreaLayoutGuide of a view that paints its background
    // according to the Theme to inset our content. This paints
    // the popover's full background.
    v.translatesAutoresizingMaskIntoConstraints = NO;
    MoThemeView *view = [MoThemeView new];
    [view addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.bottomAnchor],
        [v.leftAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.leftAnchor],
        [v.rightAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.rightAnchor],
    ]];
    self.view = view;
}

- (void)buttonAction:(id)sender
{
    // Close the popover before changing the date, and without animation
    // so it detaches from Itsycal's window right away. Changing the date
    // resizes and then moves Itsycal's window, and while the popover is
    // attached, the move can't happen in the same screen update as the
    // resize, so the window visibly resizes and then jumps.
    // Closing can deallocate us, so get what we need first.
    MoCalendar *moCal = _moCal;
    MoDate date = MakeDateWithNSDate(_picker.dateValue, _nsCal);
    NSPopover *popover = self.enclosingPopover;
    popover.animates = NO;
    [popover close];
    moCal.selectedDate = date;
}

@end
