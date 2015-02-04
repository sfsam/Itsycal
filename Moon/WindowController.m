//
//  WindowController.m
//  Moon
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "WindowController.h"
#import "Itsycal.h"
#import "ItsycalWindow.h"

@implementation WindowController
{
    NSStatusItem *_statusItem;
    NSRect _menuItemFrame, _screenFrame;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.window = [ItsycalWindow new];
        self.window.delegate = self;
    }
    return self;
}

- (void)startup
{
    NSLog(@"%s", __FUNCTION__);
    
    [self createStatusItem];
}

#pragma mark -
#pragma mark Local notification handlers

- (void)statusItemMoved:(NSNotification *)note
{
    NSLog(@"%s", __FUNCTION__);
    [self updateStatusItemPositionInfo];
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenMaxX:NSMaxX(_screenFrame)];
}

- (void)statusItemClicked:(NSNotification *)note
{
    NSLog(@"%s", __FUNCTION__);
    if ([self.itsycalWindow occlusionState] & NSWindowOcclusionStateVisible) {
        [self.itsycalWindow orderOut:nil];
    }
    else {
        [self.itsycalWindow makeKeyAndOrderFront:nil];
    }
}

#pragma mark -
#pragma mark Utilities

- (void)createStatusItem
{
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.button.target = self;
    _statusItem.button.action = @selector(statusItemClicked:);
    _statusItem.highlightMode = NO; // Deprecated in 10.10, but what is alternative?
    [self updateMenubarIcon];
    [self updateStatusItemPositionInfo];
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenMaxX:NSMaxX(_screenFrame)];
    
    // Notification for when status item view moves
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusItemMoved:) name:NSWindowDidMoveNotification object:_statusItem.button.window];
}

- (void)removeStatusItem
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidMoveNotification object:_statusItem.button.window];
    [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
    _statusItem = nil;
}

- (void)updateStatusItemPositionInfo
{
    _menuItemFrame = [_statusItem.button.window convertRectToScreen:_statusItem.button.frame];
    _screenFrame = [[NSScreen mainScreen] frame];
}

- (void)updateMenubarIcon
{
    int day = 12;
    NSImage *datesImage = [NSImage imageNamed:@"dates"];
    NSImage *icon = ItsycalDateIcon(day, datesImage);
    _statusItem.button.image = icon;
}

- (ItsycalWindow *)itsycalWindow
{
    return (ItsycalWindow *)self.window;
}

#pragma mark -
#pragma mark NSWindowDelegate

- (void)windowDidResize:(NSNotification *)notification
{
    [self.itsycalWindow positionRelativeToRect:_menuItemFrame screenMaxX:NSMaxX(_screenFrame)];
}

@end
