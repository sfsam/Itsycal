//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAppearanceVC.h"
#import "Itsycal.h"
#import "HighlightPicker.h"
#import "MoVFLHelper.h"
#import "Themer.h"
#import "Sizer.h"
#import "MoUtils.h"

@implementation PrefsAppearanceVC
{
    NSTextField *_dateTimeFormat;
    NSButton *_hideIcon;
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
        [v addSubview:chkbx];
        return chkbx;
    };
    
    NSTextField *menubarLabel = [NSTextField labelWithString:NSLocalizedString(@"Menu Bar", @"")];
    NSTextField *calendarLabel = [NSTextField labelWithString:NSLocalizedString(@"Calendar", @"")];
    menubarLabel.font = [NSFont boldSystemFontOfSize:menubarLabel.font.pointSize-1];
    calendarLabel.font = [NSFont boldSystemFontOfSize:calendarLabel.font.pointSize-1];
    [v addSubview:menubarLabel];
    [v addSubview:calendarLabel];

    NSBox *separator0 = [NSBox new];
    NSBox *separator1 = [NSBox new];
    separator0.boxType = separator1.boxType = NSBoxSeparator;
    [v addSubview:separator0];
    [v addSubview:separator1];

    // Checkboxes
    NSButton *useOutlineIcon = chkbx(NSLocalizedString(@"Use outline icon", @""));
    NSButton *showMonth = chkbx(NSLocalizedString(@"Show month in icon", @""));
    NSButton *showDayOfWeek = chkbx(NSLocalizedString(@"Show day of week in icon", @""));
    NSButton *showEventDots = chkbx(NSLocalizedString(@"Show event dots", @""));
    NSButton *useColoredDots = chkbx(NSLocalizedString(@"Use colored dots", @""));
    NSButton *showWeeks = chkbx(NSLocalizedString(@"Show calendar weeks", @""));
    NSButton *showLocation = chkbx(NSLocalizedString(@"Show event location", @""));
    _hideIcon = chkbx(NSLocalizedString(@"Hide icon", @""));

    // Datetime format text field
    _dateTimeFormat = [NSTextField textFieldWithString:@""];
    _dateTimeFormat.placeholderString = NSLocalizedString(@"Datetime pattern", @"");
    _dateTimeFormat.refusesFirstResponder = YES;
    _dateTimeFormat.bezelStyle = NSTextFieldRoundedBezel;
    _dateTimeFormat.usesSingleLineMode = YES;
    _dateTimeFormat.delegate = self;
    [v addSubview:_dateTimeFormat];

    // Datetime help button
    NSButton *helpButton = [NSButton buttonWithTitle:@"" target:self action:@selector(openHelpPage:)];
    helpButton.bezelStyle = NSBezelStyleHelpButton;
    [v addSubview:helpButton];

    // Highlight control
    HighlightPicker *highlight = [HighlightPicker new];
    highlight.target = self;
    highlight.action = @selector(didChangeHighlight:);
    [v addSubview:highlight];

    // Theme label
    NSTextField *themeLabel = [NSTextField labelWithString:NSLocalizedString(@"Theme:", @"")];
    [v addSubview:themeLabel];

    // Theme popup
    NSPopUpButton *themePopup = [NSPopUpButton new];
    [themePopup addItemWithTitle:NSLocalizedString(@"System", @"System theme name")];
    [themePopup addItemWithTitle:NSLocalizedString(@"Light", @"Light theme name")];
    [themePopup addItemWithTitle:NSLocalizedString(@"Dark", @"Dark theme name")];
    // The tags will be used to bind the selected theme
    // preference to NSUserDefaults.
    [themePopup itemAtIndex:0].tag = ThemePreferenceSystem;
    [themePopup itemAtIndex:1].tag = ThemePreferenceLight;
    [themePopup itemAtIndex:2].tag = ThemePreferenceDark;
    [v addSubview:themePopup];
    
    // Size labels
    NSTextField *sizeMinLabel = [NSTextField labelWithString:@"Aa"];
    NSTextField *sizeMaxLabel = [NSTextField labelWithString:@"Aa"];
    sizeMinLabel.font = [NSFont systemFontOfSize:FONT_SIZE_SMALL];
    sizeMaxLabel.font = [NSFont systemFontOfSize:FONT_SIZE_LARGE];
    [v addSubview:sizeMinLabel];
    [v addSubview:sizeMaxLabel];

    // Text size slider
    NSSlider *sizeSlider = [NSSlider sliderWithValue:0 minValue:FONT_SIZE_SMALL maxValue:FONT_SIZE_LARGE target:nil action:NULL];
    sizeSlider.sliderType = NSSliderTypeLinear;
    sizeSlider.numberOfTickMarks = 3; // SizePreferenceSmall=0, Medium=1, Large=2
    sizeSlider.allowsTickMarkValuesOnly = YES;
    sizeSlider.minValue = SizePreferenceSmall;  // = 0
    sizeSlider.maxValue = SizePreferenceLarge;  // = 2
    [v addSubview:sizeSlider];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20, @"mm": @40} views:NSDictionaryOfVariableBindings(menubarLabel, calendarLabel, separator0, separator1, useOutlineIcon, showMonth, showDayOfWeek, showEventDots, useColoredDots, showWeeks, showLocation, _dateTimeFormat, helpButton, _hideIcon, highlight, themeLabel, themePopup, sizeMinLabel, sizeSlider, sizeMaxLabel)];
    [vfl :@"V:|-m-[menubarLabel]-10-[useOutlineIcon]-[showMonth]-[showDayOfWeek]-[_dateTimeFormat]-[_hideIcon]-m-[calendarLabel]-10-[sizeSlider]-15-[themePopup]-m-[highlight]-m-[showEventDots]-[useColoredDots]-[showLocation]-[showWeeks]-m-|"];
    [vfl :@"H:|-m-[menubarLabel]-[separator0]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[calendarLabel]-[separator1]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[useOutlineIcon]-(>=m)-|"];
    [vfl :@"H:|-m-[showMonth]-(>=m)-|"];
    [vfl :@"H:|-m-[showDayOfWeek]-(>=m)-|"];
    [vfl :@"H:|-m-[_dateTimeFormat]-[helpButton]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[_hideIcon]-(>=m)-|"];
    [vfl :@"H:|-m-[highlight]-(>=m)-|"];
    [vfl :@"H:|-(>=m)-[sizeMinLabel]-[sizeSlider(90)]-[sizeMaxLabel]-(>=m)-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[themeLabel]-[themePopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[showEventDots]-(>=m)-|"];
    [vfl :@"H:|-mm-[useColoredDots]-(>=m)-|"];
    [vfl :@"H:|-m-[showWeeks]-(>=m)-|"];
    [vfl :@"H:|-m-[showLocation]-(>=m)-|"];

    [v.centerXAnchor constraintEqualToAnchor:sizeSlider.centerXAnchor].active = YES;

    // Bindings for icon preferences
    [useOutlineIcon bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kUseOutlineIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [showMonth bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowMonthInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [showDayOfWeek bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowDayOfWeekInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_hideIcon bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bind icon prefs enabled state to hide icon's value
    [useOutlineIcon bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    [showMonth bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    [showDayOfWeek bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];

    // Binding for datetime format
    [_dateTimeFormat bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kClockFormat] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSMultipleValuesPlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNoSelectionPlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNotApplicablePlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNullPlaceholderBindingOption: _dateTimeFormat.placeholderString}];

    // Bindings for showEventDots preference
    [showEventDots bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for useColoredDots preference
    [useColoredDots bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kUseColoredDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [useColoredDots bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showWeeks preference
    [showWeeks bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowWeeks] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showLocation preference
    [showLocation bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowLocation] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    // Bindings for highlight picker
    [highlight bind:@"weekStartDOW" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWeekStartDOW] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [highlight bind:@"selectedDOWs" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHighlightedDOWs] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for theme
    [themePopup bind:@"selectedTag" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kThemePreference] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    // Bindings for size
    [sizeSlider bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kSizePreference] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    
    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
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
