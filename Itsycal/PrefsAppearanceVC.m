//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAppearanceVC.h"
#import "Itsycal.h"
#import "MoView.h"
#import "MoTextField.h"

@implementation PrefsAppearanceVC
{
    NSButton *_useOutlineIcon;
    NSButton *_showMonth;
    NSButton *_showDayOfWeek;
    NSButton *_highlightWeekends;
    NSButton *_showWeeks;
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    MoView *v = [MoView new];

    v.translatesAutoresizingMaskIntoConstraints = YES;

    // Convenience function for making checkboxes.
    NSButton* (^chkbx)(NSString *) = ^NSButton* (NSString *title) {
        NSButton *chkbx = [NSButton checkboxWithTitle:title target:self action:nil];
        chkbx.translatesAutoresizingMaskIntoConstraints = NO;
        [v addSubview:chkbx];
        return chkbx;
    };
    
    // Checkboxes
    _useOutlineIcon = chkbx(NSLocalizedString(@"Use outline icon", @""));
    _showMonth = chkbx(NSLocalizedString(@"Show month in icon", @""));
    _showDayOfWeek = chkbx(NSLocalizedString(@"Show day of week in icon", @""));
    _highlightWeekends = chkbx(NSLocalizedString(@"Highlight weekend", @""));
    _showWeeks = chkbx(NSLocalizedString(@"Show calendar weeks", @""));

    // Convenience function to make visual constraints.
    void (^vcon)(NSString*) = ^(NSString *format) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(_useOutlineIcon, _showMonth, _showDayOfWeek, _highlightWeekends, _showWeeks)]];
    };
    vcon(@"V:|-m-[_useOutlineIcon]-[_showMonth]-[_showDayOfWeek]-20-[_highlightWeekends]-[_showWeeks]-m-|");
    vcon(@"H:|-m-[_useOutlineIcon]-(>=m)-|");
    vcon(@"H:|-m-[_showMonth]-(>=m)-|");
    vcon(@"H:|-m-[_showDayOfWeek]-(>=m)-|");
    vcon(@"H:|-m-[_highlightWeekends]-(>=m)-|");
    vcon(@"H:|-m-[_showWeeks]-(>=m)-|");

    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    // Bindings for icon preferences
    [_useOutlineIcon bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kUseOutlineIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showMonth bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowMonthInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showDayOfWeek bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowDayOfWeekInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for week/weekends preferences
    [_highlightWeekends bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHighlightWeekend] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showWeeks bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowWeeks] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
}

@end
