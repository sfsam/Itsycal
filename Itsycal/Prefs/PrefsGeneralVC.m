//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsGeneralVC.h"
#import "Itsycal.h"
#import "MoLoginItem.h"
#import "MoVFLHelper.h"
#import "MASShortcut/Shortcut.h"
#import "Sparkle/SUUpdater.h"

@implementation PrefsGeneralVC
{
    NSButton *_login;
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

    // Checkboxes
    _login = chkbx(NSLocalizedString(@"Launch at login", @""));
    _login.action = @selector(launchAtLogin:);
    NSButton *checkUpdates = chkbx(NSLocalizedString(@"Automatically check for updates", @""));
    NSButton *beepBeep = chkbx(NSLocalizedString(@"Beep beep on the hour", @""));

    // Shortcut label
    NSTextField *shortcutLabel = label(NSLocalizedString(@"Keyboard shortcut", @""));

    // Shortcut view
    MASShortcutView *shortcutView = [MASShortcutView new];
    [shortcutView setAssociatedUserDefaultsKey:kKeyboardShortcut withTransformerName:MASDictionaryTransformerName];
    [v addSubview:shortcutView];

    // Window position label
    NSTextField *positionLabel = label(NSLocalizedString(@"Window position:", @""));

    // Window position popup
    NSPopUpButton *positionPopup = [NSPopUpButton new];
    [positionPopup addItemsWithTitles:@[NSLocalizedString(@"Below menu bar icon", @""),
                                        NSLocalizedString(@"Top right of screen", @"")]];
    // The tags will be used to bind the selected window
    // position preference to NSUserDefaults.
    [positionPopup itemAtIndex:0].tag = WindowPositionBelowMenuBarIcon;
    [positionPopup itemAtIndex:1].tag = WindowPositionTopRightOfScreen;
    [positionPopup.cell setAccessibilityTitleUIElement:positionLabel.cell];
    [v addSubview:positionPopup];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(_login, checkUpdates, beepBeep, shortcutLabel, shortcutView, positionLabel, positionPopup)];
    [vfl :@"V:|-m-[_login]-[checkUpdates]-[beepBeep]-m-[shortcutLabel]-3-[shortcutView(25)]-30-[positionPopup]-m-|"];
    [vfl :@"H:|-m-[_login]-(>=m)-|"];
    [vfl :@"H:|-m-[checkUpdates]-(>=m)-|"];
    [vfl :@"H:|-m-[beepBeep]-(>=m)-|"];
    [vfl :@"H:|-(>=m)-[shortcutLabel]-(>=m)-|"];
    [vfl :@"H:|-m-[shortcutView(>=220)]-m-|"];
    [vfl :@"H:|-m-[positionLabel]-[positionPopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];

    // Center shortcutLabel
    [v addConstraint:[NSLayoutConstraint constraintWithItem:shortcutLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    // Binding for Sparkle automatic update checks
    [checkUpdates bind:@"value" toObject:[SUUpdater sharedUpdater] withKeyPath:@"automaticallyChecksForUpdates" options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Binding for hourly beep
    [beepBeep bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kBeepBeepOnTheHour] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for window position
    [positionPopup bind:@"selectedTag" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWindowPosition] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];

    // The API used to check the login item's state (LSSharedFileList) causes
    // errors for users who have network drives but are not connected to their
    // network (github.com/sfsam/Itsycal/issues/15). Give them an option to
    // disable this check.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDoNotCheckLoginItemStatus] == NO) {
        _login.hidden = NO;
        _login.state = MOIsLoginItemEnabled() ? NSControlStateValueOn : NSControlStateValueOff;
    }
    else {
        _login.hidden = YES;
    }
}

#pragma mark -
#pragma mark Login item

- (void)launchAtLogin:(NSButton *)login
{
    MOEnableLoginItem(login.state == NSControlStateValueOn);
}

@end
