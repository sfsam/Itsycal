//
//  Created by Sanjay Madan on 1/9/24.
//  Copyright © 2024 mowglii.com. All rights reserved.
//

#import "DatePickerVC.h"
#import "MoVFLHelper.h"
#import "Themer.h"

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

    NSImage *sym = [NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:@""];
    NSButton *btn = [NSButton buttonWithImage:sym target:self action:@selector(buttonAction:)];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.keyEquivalent = @"\r";
    [v addSubview:btn];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:nil views:NSDictionaryOfVariableBindings(_picker, label, btn)];
    [vfl :@"H:|-10-[_picker]-[btn]-10-|" :NSLayoutFormatAlignAllLastBaseline];
    [vfl :@"V:|-10-[label]-[_picker]-10-|" :NSLayoutFormatAlignAllLeading];

    self.view = v;
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

- (void)buttonAction:(id)sender
{
    _moCal.selectedDate = MakeDateWithNSDate(_picker.dateValue, _nsCal);
    [self.enclosingPopover close];
}

@end
