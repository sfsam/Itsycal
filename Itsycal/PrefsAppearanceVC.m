//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAppearanceVC.h"
#import "Itsycal.h"
#import "HighlightPicker.h"
#import "MoVFLHelper.h"
#import "Themer.h"
#import "MoUtils.h"

@implementation PrefsAppearanceVC
{
    NSButton *_useOutlineIcon;
    NSButton *_showMonth;
    NSButton *_showDayOfWeek;
    NSTextField *_dateTimeFormat;
    NSButton *_hideIcon;
    HighlightPicker *_highlight;
    NSButton *_showEventDots;
    NSButton *_showWeeks;
    NSButton *_showLocation;
    NSPopUpButton *_themePopup;
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];

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
    _showEventDots = chkbx(NSLocalizedString(@"Show event dots", @""));
    _showWeeks = chkbx(NSLocalizedString(@"Show calendar weeks", @""));
    _showLocation = chkbx(NSLocalizedString(@"Show event location", @""));
    _hideIcon = chkbx(NSLocalizedString(@"Hide icon", @""));

    // Datetime format text field
    _dateTimeFormat = [NSTextField textFieldWithString:@""];
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

    // Highlight control
    _highlight = [HighlightPicker new];
    _highlight.translatesAutoresizingMaskIntoConstraints = NO;
    _highlight.target = self;
    _highlight.action = @selector(didChangeHighlight:);
    [v addSubview:_highlight];

    // Theme label
    NSTextField *themeLabel = [NSTextField labelWithString:NSLocalizedString(@"Theme:", @"")];
    themeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:themeLabel];

    // Theme popup
    _themePopup = [NSPopUpButton new];
    _themePopup.translatesAutoresizingMaskIntoConstraints = NO;
    // On macOS 10.14+, there is a System theme preference in
    // addition to Light and Dark.
    if (OSVersionIsAtLeast(10, 14, 0)) {
        [_themePopup addItemWithTitle:NSLocalizedString(@"System", @"System theme name")];
    }
    [_themePopup addItemWithTitle:NSLocalizedString(@"Light", @"Light theme name")];
    [_themePopup addItemWithTitle:NSLocalizedString(@"Dark", @"Dark theme name")];
    // The tags will be used to bind the selected theme
    // preference to NSUserDefaults.
    if (OSVersionIsAtLeast(10, 14, 0)) {
        [_themePopup itemAtIndex:0].tag = 0; // System
        [_themePopup itemAtIndex:1].tag = 1; // Light
        [_themePopup itemAtIndex:2].tag = 2; // Dark
    }
    else {
        [_themePopup itemAtIndex:0].tag = 1; // Light
        [_themePopup itemAtIndex:1].tag = 2; // Dark
    }
    [v addSubview:_themePopup];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(_useOutlineIcon, _showMonth, _showDayOfWeek, _showEventDots, _showWeeks, _showLocation, _dateTimeFormat, helpButton, _hideIcon, _highlight, themeLabel, _themePopup)];
    [vfl :@"V:|-m-[_useOutlineIcon]-[_showMonth]-[_showDayOfWeek]-m-[_dateTimeFormat]-[_hideIcon]-m-[_highlight]-m-[_themePopup]-m-[_showEventDots]-[_showLocation]-[_showWeeks]-m-|"];
    [vfl :@"H:|-m-[_useOutlineIcon]-(>=m)-|"];
    [vfl :@"H:|-m-[_showMonth]-(>=m)-|"];
    [vfl :@"H:|-m-[_showDayOfWeek]-(>=m)-|"];
    [vfl :@"H:|-m-[_dateTimeFormat]-[helpButton]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[_hideIcon]-(>=m)-|"];
    [vfl :@"H:|-m-[_highlight]-(>=m)-|"];
    [vfl :@"H:|-m-[themeLabel]-[_themePopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[_showEventDots]-(>=m)-|"];
    [vfl :@"H:|-m-[_showWeeks]-(>=m)-|"];
    [vfl :@"H:|-m-[_showLocation]-(>=m)-|"];

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

    // Bindings for showEventDots preference
    [_showEventDots bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showWeeks preference
    [_showWeeks bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowWeeks] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showLocation preference
    [_showLocation bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowLocation] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    // Bindings for highlight picker
    [_highlight bind:@"weekStartDOW" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWeekStartDOW] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_highlight bind:@"selectedDOWs" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHighlightedDOWs] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for theme
    [_themePopup bind:@"selectedTag" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kThemePreference] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
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

- (void)didChangeHighlight:(HighlightPicker *)picker
{
    [[NSUserDefaults standardUserDefaults] setInteger:picker.selectedDOWs forKey:kHighlightedDOWs];
}

@end
