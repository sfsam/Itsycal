//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAppearanceVC.h"
#import "Itsycal.h"
#import "Themer.h"
#import "Sizer.h"
#import "HighlightPicker.h"
#import "MoVFLHelper.h"
#import "IconIsConfigurableTransformer.h"

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

    // Convenience function for making labels.
    NSTextField* (^label)(NSString*) = ^NSTextField* (NSString *stringValue) {
        NSTextField *txt = [NSTextField labelWithString:stringValue];
        [v addSubview:txt];
        return txt;
    };

    // Convenience function for making checkboxes.
    NSButton* (^chkbx)(NSString *) = ^NSButton* (NSString *title) {
        NSButton *chkbx = [NSButton checkboxWithTitle:title target:self action:nil];
        [v addSubview:chkbx];
        return chkbx;
    };

    // Convenience function for making popups whose selected item's
    // tag is bound to the NSUserDefaults value for key.
    NSPopUpButton* (^popup)(NSArray<NSString *> *, NSArray<NSNumber *> *, NSString *) = ^NSPopUpButton* (NSArray<NSString *> *titles, NSArray<NSNumber *> *tags, NSString *key) {
        NSParameterAssert(titles.count == tags.count);
        NSPopUpButton *popup = [NSPopUpButton new];
        [popup addItemsWithTitles:titles];
        for (NSUInteger i = 0; i < tags.count; i++) {
            [popup itemAtIndex:i].tag = tags[i].integerValue;
        }
        [popup bind:@"selectedTag" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:key] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
        [v addSubview:popup];
        return popup;
    };

    // Theme label
    NSTextField *themeLabel = label(NSLocalizedString(@"Theme:", @""));

    // Theme popup
    NSPopUpButton *themePopup = popup(@[NSLocalizedString(@"System", @"System theme name"),
                                        NSLocalizedString(@"Light", @"Light theme name"),
                                        NSLocalizedString(@"Dark", @"Dark theme name")],
                                      @[@(ThemePreferenceSystem), @(ThemePreferenceLight), @(ThemePreferenceDark)],
                                      kThemePreference);

    // Size label
    NSTextField *sizeLabel = label(NSLocalizedString(@"Size:", @"Text size label"));

    // Size popup
    NSPopUpButton *sizePopup = popup(@[NSLocalizedString(@"Small", @"Small text size"),
                                       NSLocalizedString(@"Medium", @"Medium text size"),
                                       NSLocalizedString(@"Large", @"Large text size")],
                                     @[@(SizePreferenceSmall), @(SizePreferenceMedium), @(SizePreferenceLarge)],
                                     kSizePreference);

    NSTextField *menubarLabel = label(NSLocalizedString(@"Menu Bar", @""));
    NSTextField *calendarLabel = label(NSLocalizedString(@"Calendar", @""));
    menubarLabel.font = [NSFont boldSystemFontOfSize:menubarLabel.font.pointSize-1];
    calendarLabel.font = [NSFont boldSystemFontOfSize:calendarLabel.font.pointSize-1];

    NSBox *separator0 = [NSBox new];
    NSBox *separator1 = [NSBox new];
    separator0.boxType = separator1.boxType = NSBoxSeparator;
    [v addSubview:separator0];
    [v addSubview:separator1];

    // Icon picker segmented control
    NSSegmentedControl *iconPicker = [NSSegmentedControl segmentedControlWithImages:@[
        [NSImage imageNamed:@"menubaricon0"],
        [NSImage imageNamed:@"menubaricon1"],
        [NSImage imageNamed:@"menubaricon2"],
        [NSImage imageNamed:@"menubaricon3"]
    ] trackingMode:NSSegmentSwitchTrackingSelectOne target:nil action:nil];
    [iconPicker setSelectedSegment:0]; // will be set by binding below.
    [v addSubview:iconPicker];

    // Checkboxes
    NSButton *showMonth = chkbx(NSLocalizedString(@"Show month in icon", @""));
    NSButton *showDayOfWeek = chkbx(NSLocalizedString(@"Show day of week in icon", @""));
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

    // First day of week label
    NSTextField *firstDayLabel = label(NSLocalizedString(@"First day of week:", @""));

    // First day of week popup
    NSPopUpButton *firstDayPopup = [NSPopUpButton new];
    [firstDayPopup addItemsWithTitles:@[NSLocalizedString(@"Sunday", @""),
                                        NSLocalizedString(@"Monday", @""),
                                        NSLocalizedString(@"Tuesday", @""),
                                        NSLocalizedString(@"Wednesday", @""),
                                        NSLocalizedString(@"Thursday", @""),
                                        NSLocalizedString(@"Friday", @""),
                                        NSLocalizedString(@"Saturday", @"")]];
    [v addSubview:firstDayPopup];

    // Highlight control
    HighlightPicker *highlight = [HighlightPicker new];
    highlight.target = self;
    highlight.action = @selector(didChangeHighlight:);
    [v addSubview:highlight];

    // Calendar checkboxes
    NSButton *showEventDots = chkbx(NSLocalizedString(@"Show event dots", @""));
    NSButton *useColoredDots = chkbx(NSLocalizedString(@"Use colored dots", @""));
    NSButton *showWeeks = chkbx(NSLocalizedString(@"Show calendar weeks", @""));

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20, @"mm": @40} views:NSDictionaryOfVariableBindings(themeLabel, themePopup, sizeLabel, sizePopup, menubarLabel, calendarLabel, separator0, separator1, iconPicker, showMonth, showDayOfWeek, _dateTimeFormat, helpButton, _hideIcon, firstDayLabel, firstDayPopup, highlight, showWeeks, showEventDots, useColoredDots)];
    [vfl :@"V:|-m-[themePopup]-m-[menubarLabel]-10-[iconPicker]-[showMonth]-[showDayOfWeek]-[_dateTimeFormat]-[_hideIcon]-m-[calendarLabel]-10-[firstDayPopup]-m-[highlight]-m-[showEventDots]-[useColoredDots]-[showWeeks]-m-|"];
    [vfl :@"H:|-m-[themeLabel]-[themePopup]-m-[sizeLabel]-[sizePopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[menubarLabel]-[separator0]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[calendarLabel]-[separator1]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[iconPicker]-m-|"];
    [vfl :@"H:|-m-[showMonth]-(>=m)-|"];
    [vfl :@"H:|-m-[showDayOfWeek]-(>=m)-|"];
    [vfl :@"H:|-m-[_dateTimeFormat]-[helpButton]-m-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[_hideIcon]-(>=m)-|"];
    [vfl :@"H:|-m-[firstDayLabel]-[firstDayPopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[highlight]-(>=m)-|"];
    [vfl :@"H:|-m-[showEventDots]-(>=m)-|"];
    [vfl :@"H:|-mm-[useColoredDots]-(>=m)-|"];
    [vfl :@"H:|-m-[showWeeks]-(>=m)-|"];

    // Bindings for icon preferences
    [iconPicker bind:@"selectedIndex" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kMenuBarIconType] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSNoSelectionPlaceholderBindingOption: @0}];
    [showMonth bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowMonthInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [showDayOfWeek bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowDayOfWeekInIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [_hideIcon bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bind icon prefs enabled state to kHideIcon's value
    [iconPicker bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    [showMonth bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    [showDayOfWeek bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHideIcon] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];

    // Bind icon prefs enabled state to kMenuBarIconType's value
    IconIsConfigurableTransformer *iconIsConfigurableTransformer = [IconIsConfigurableTransformer new];
    [showMonth bind:@"enabled2" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kMenuBarIconType] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerBindingOption: iconIsConfigurableTransformer}];
    [showDayOfWeek bind:@"enabled2" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kMenuBarIconType] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSValueTransformerBindingOption: iconIsConfigurableTransformer}];

    // Binding for datetime format
    [_dateTimeFormat bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kClockFormat] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES), NSMultipleValuesPlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNoSelectionPlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNotApplicablePlaceholderBindingOption: _dateTimeFormat.placeholderString, NSNullPlaceholderBindingOption: _dateTimeFormat.placeholderString}];

    // Bindings for first day of week
    [firstDayPopup bind:@"selectedIndex" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWeekStartDOW] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for highlight picker
    [highlight bind:@"weekStartDOW" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWeekStartDOW] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [highlight bind:@"selectedDOWs" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kHighlightedDOWs] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showEventDots preference
    [showEventDots bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for useColoredDots preference
    [useColoredDots bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kUseColoredDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [useColoredDots bind:@"enabled" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowEventDots] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for showWeeks preference
    [showWeeks bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kShowWeeks] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

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
