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
    NSTextField *_dateTimeFormat;
    NSButton *_hideIcon;
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
    _hideIcon = chkbx(NSLocalizedString(@"Hide icon", @""));

    // Datetime format text field
    _dateTimeFormat = [NSTextField textFieldWithString:nil];
    _dateTimeFormat.translatesAutoresizingMaskIntoConstraints = false;
    _dateTimeFormat.placeholderString = NSLocalizedString(@"Datetime pattern", @"");
    _dateTimeFormat.refusesFirstResponder = YES;
    _dateTimeFormat.bezelStyle = NSTextFieldRoundedBezel;
    _dateTimeFormat.usesSingleLineMode = YES;
    _dateTimeFormat.delegate = self;
    [v addSubview:_dateTimeFormat];

    // Datetime help button
    NSButton *helpButton = [NSButton new];
    helpButton.title = @"";
    helpButton.translatesAutoresizingMaskIntoConstraints = false;
    helpButton.bezelStyle = NSHelpButtonBezelStyle;
    helpButton.target = self;
    helpButton.action = @selector(openHelpPage:);
    [v addSubview:helpButton];

    // Convenience function to make visual constraints.
    void (^vcon)(NSString*) = ^(NSString *format) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(_useOutlineIcon, _showMonth, _showDayOfWeek, _highlightWeekends, _showWeeks, _dateTimeFormat, helpButton, _hideIcon)]];
    };
    vcon(@"V:|-m-[_useOutlineIcon]-[_showMonth]-[_showDayOfWeek]-m-[_dateTimeFormat]-[_hideIcon]-m-[_highlightWeekends]-[_showWeeks]-m-|");
    vcon(@"H:|-m-[_useOutlineIcon]-(>=m)-|");
    vcon(@"H:|-m-[_showMonth]-(>=m)-|");
    vcon(@"H:|-m-[_showDayOfWeek]-(>=m)-|");
    vcon(@"H:|-m-[_highlightWeekends]-(>=m)-|");
    vcon(@"H:|-m-[_showWeeks]-(>=m)-|");
    vcon(@"H:|-m-[_dateTimeFormat]-[helpButton]-m-|");
    vcon(@"H:|-m-[_hideIcon]-(>=m)-|");

    // Center dateTime format and help button vertically.
    [v addConstraint:[NSLayoutConstraint constraintWithItem:helpButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_dateTimeFormat attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];

    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    // Bindings for icon preferences
    [_useOutlineIcon bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kUseOutlineIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showMonth bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowMonthInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showDayOfWeek bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowDayOfWeekInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_hideIcon bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bind icon prefs enabled state to hide icon's value
    [_useOutlineIcon bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    [_showMonth bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    [_showDayOfWeek bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];

    // Binding for datetime format
    [_dateTimeFormat bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kClockFormat] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSMultipleValuesPlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNoSelectionPlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNotApplicablePlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNullPlaceholderBindingOption: _dateTimeFormat.placeholderString}];

    // Bindings for week/weekends preferences
    [_highlightWeekends bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHighlightWeekend] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_showWeeks bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowWeeks] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    [self updateHideIconState];

    // We don't want _dateTimeFormat to be first responder.
    [self.view.window makeFirstResponder:nil];
}

- (void)openHelpPage:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://mowglii.com/itsycal/datetime.html"]];
}

- (void)updateHideIconState
{
    NSString *dateTimeFormat = _dateTimeFormat.stringValue;
    if (dateTimeFormat == nil || [dateTimeFormat isEqualToString:@""]) {
        [_hideIcon setState:0];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kHideIcon];
        // Hack alert:
        // We call -performSelector... instead of calling _hideIcon's
        // -setEnabled: directly. Calling directly didn't work. Perhaps
        // this has to do with the fact that _hideIcon's value is bound
        // to NSUserDefaults which is mutated. By calling -setEnabled on
        // the next turn of the runloop, we are able to disbale _hideIcon.
        [self performSelectorOnMainThread:@selector(disableHideIcon:) withObject:nil waitUntilDone:NO];
    }
    else {
        [_hideIcon setEnabled:YES];
    }
}

- (void)disableHideIcon:(id)sender
{
    [_hideIcon setEnabled:NO];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    [self updateHideIconState];
}

@end
