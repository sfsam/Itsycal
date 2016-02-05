//
//  ItsycalExtra.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/9/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "ItsycalExtra.h"
#import "NSMenuExtraView.h"
#import "Itsycal.h"

@implementation ItsycalExtra
{
    BOOL _itsycalIsRunning;
}

- (id)initWithBundle:(NSBundle *)bundle
{
    self = [super initWithBundle:bundle];
    if (self) {
        _itsycalIsRunning = NO;
        
        // Setup menu extra view with blank image.
        NSMenuExtraView *exView;
        NSImage *iconImage = ItsycalIconImageForText(@"-");

        NSRect frame = self.view.frame;
        frame.size.width = iconImage.size.width;
        self.view.frame = frame;
        
        exView = [[NSMenuExtraView alloc] initWithFrame:self.view.frame menuExtra:self];
        exView.image = iconImage;
        
        self.view = exView;
        
        // Menu extra moved notification
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuExtraMoved:) name:NSViewDidUpdateTrackingAreasNotification object:self.view];
        
        // Register for Itsycal notifications.
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(itsycalIsActive:) name:ItsycalIsActiveNotification object:nil];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(menubarIconUpdated:) name:ItsycalDidUpdateIconNotification object:nil];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShortcutActivated:) name:ItsycalKeyboardShortcutNotification object:nil];
        
        // If Itsycal is running, we want to know when it has terminated.
        [[NSWorkspace sharedWorkspace] addObserver:self forKeyPath:@"runningApplications" options:0 context:NULL];
        
        // Tell Itsycal we're alive so it can remove it's status item.
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalExtraIsActiveNotification object:nil userInfo:[self menuExtraPositionInfo] deliverImmediately:YES];

    }
    return self;
}

- (void)willUnload
{
    // Notify Itsycal that menu extra is going away.
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalExtraWillUnloadNotification object:nil userInfo:nil deliverImmediately:YES];
    // Clean up.
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSWorkspace sharedWorkspace] removeObserver:self forKeyPath:@"runningApplications"];
    [super willUnload];
}

#pragma mark
#pragma mark Menu

- (NSMenu *)menu
{
    NSMenu *menu = nil;
    
    if (_itsycalIsRunning) {
        // Itsycal is running, so tell it the menu icon was clicked.
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalExtraClickedNotification object:nil userInfo:[self menuExtraPositionInfo] deliverImmediately:YES];
    }
    else {
        // Itsycal is not running, so show the menu.
        menu = [NSMenu new];
        // Cannot use the NSLocalizedstring() macro because it uses
        // [NSBundle mainBundle] so we use what it expands into and
        // substitute in [self bundle] instead.
        NSMenuItem *item = [menu addItemWithTitle:[[self bundle] localizedStringForKey:@"Open Itsycal..." value:@"" table:nil] action:@selector(openItsycal:) keyEquivalent:@""];
        item.target = self;
    }
    return menu;
}

- (void)openItsycal:(id)sender
{
    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:kItsycalBundleID options:NSWorkspaceLaunchWithoutActivation additionalEventParamDescriptor:nil launchIdentifier:NULL];
}

#pragma mark
#pragma mark MenuExtra

- (void)menuExtraMoved:(NSNotification *)notification
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalExtraDidMoveNotification object:nil userInfo:[self menuExtraPositionInfo] deliverImmediately:YES];
}

- (NSDictionary *)menuExtraPositionInfo
{
    NSRect mextraInWindowCoords = [self.view convertRect:self.view.frame toView:nil];
    NSRect mextraInScreenCoords = [self.view.window convertRectToScreen:mextraInWindowCoords];
    NSRect screenInScreenCoords = [[NSScreen mainScreen] frame];
    return @{@"menuItemFrame": NSStringFromRect(mextraInScreenCoords),
             @"screenFrame":   NSStringFromRect(screenInScreenCoords)};
}

#pragma mark
#pragma mark Distributed Notification handlers

- (void)itsycalIsActive:(NSNotification *)notification
{
    // Update our icon
    [self menubarIconUpdated:notification];
    
    // Reply to Itsycal so it can remove it's status item
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalExtraIsActiveNotification object:nil userInfo:[self menuExtraPositionInfo] deliverImmediately:YES];
}

- (void)menubarIconUpdated:(NSNotification *)notification
{
    _itsycalIsRunning = YES;
    NSString *iconText = notification.userInfo[@"iconText"];
    if (iconText == nil) {
        iconText = @"?";
    }
    NSImage *iconImage = ItsycalIconImageForText(iconText);
    [(NSMenuExtraView *)self.view setImage:iconImage];
    
    // Adjust size of menu extra based on iconImage size.
    NSRect frame = self.view.frame;
    frame.size.width = iconImage.size.width;
    self.view.frame = frame;
    self.length = iconImage.size.width;
}

- (void)keyboardShortcutActivated:(NSNotification *)notification
{
    // Simulate a click on the menu extra.
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:ItsycalExtraClickedNotification object:nil userInfo:[self menuExtraPositionInfo] deliverImmediately:YES];
}

#pragma mark
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // When the running applications change, check if Itsycal is in the list.
    // If not, blank out our image and set _itsycalIsRunning to NO.
    if ([keyPath isEqualToString:@"runningApplications"]) {
        BOOL foundItsycal = NO;
        NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
        for (NSRunningApplication *runningApp in runningApps) {
            if ([runningApp.bundleIdentifier isEqualToString:kItsycalBundleID]) {
                foundItsycal = YES;
                break;
            }
        }
        if (!foundItsycal && _itsycalIsRunning) {
            _itsycalIsRunning = NO;
            
            // Display a blank icon.
            NSImage *iconImage = ItsycalIconImageForText(@"-");
            [(NSMenuExtraView *)self.view setImage:iconImage];
            
            // Adjust size of menu extra based on iconImage size.
            NSRect frame = self.view.frame;
            frame.size.width = iconImage.size.width;
            self.view.frame = frame;
            self.length = iconImage.size.width;
        }
    }
}

@end

