//
//  PrefsViewController.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "PrefsViewController.h"
#import "Itsycal.h"
#import "MASShortcutView.h"
#import "MASShortcutView+Bindings.h"
#import "MoTextField.h"

@implementation PrefsViewController
{
    NSButton *_login;
    MoTextField *_title;
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
 
    // App Icon
    NSImageView *appIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    appIcon.translatesAutoresizingMaskIntoConstraints = NO;
    appIcon.image = [NSImage imageNamed:@"AppIcon"];
    [v addSubview:appIcon];

    // Convenience function for making text fields.
    MoTextField* (^txt)(NSString*) = ^MoTextField* (NSString *stringValue) {
        MoTextField *txt = [MoTextField new];
        txt.font = [NSFont systemFontOfSize:11];
        txt.translatesAutoresizingMaskIntoConstraints = NO;
        txt.editable = NO;
        txt.bezeled = NO;
        txt.drawsBackground = NO;
        txt.stringValue = stringValue;
        [v addSubview:txt];
        return txt;
    };
    
    // Title
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    _title = txt([NSString stringWithFormat:@"Itsycal %@", infoDict[@"CFBundleShortVersionString"]]);
    _title.font = [NSFont boldSystemFontOfSize:13];
    _title.textColor = [NSColor lightGrayColor];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:_title.stringValue];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, 7)];
    _title.attributedStringValue = s;
    _title.target = self;
    _title.action = @selector(toggleTitle:);
    
    // Link
    MoTextField *link  = txt(@"mowglii.com/itsycal");
    link.font = [NSFont boldSystemFontOfSize:12];
    link.linkEnabled = YES;
    
    // Login checkbox
    _login = [NSButton new];
    _login.translatesAutoresizingMaskIntoConstraints = NO;
    _login.title = NSLocalizedString(@"Launch at login", @"");
    _login.font = [NSFont systemFontOfSize:12];
    _login.target = self;
    _login.action = @selector(launchAtLogin:);
    [_login setButtonType:NSSwitchButton];
    [v addSubview:_login];
    
    // Shortcut label
    MoTextField *shortcutLabel = txt(NSLocalizedString(@"Keyboard shortcut", @""));
    
    // Shortcut view
    MASShortcutView *shortcutView = [MASShortcutView new];
    shortcutView.translatesAutoresizingMaskIntoConstraints = NO;
    shortcutView.style = MASShortcutViewStyleTexturedRect;
    shortcutView.associatedUserDefaultsKey = kKeyboardShortcut;
    [v addSubview:shortcutView];
    
    // Copyright
    MoTextField *copyright = txt(infoDict[@"NSHumanReadableCopyright"]);
    copyright.textColor = [NSColor lightGrayColor];
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*) = ^(NSString *format) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appIcon, _title, link, _login, shortcutLabel, shortcutView, copyright)]];
    };
    vcon(@"V:|-m-[appIcon(64)]");
    vcon(@"H:|-m-[appIcon(64)]-[_title]-(>=m)-|");
    vcon(@"H:[appIcon]-[link]-(>=m)-|");
    vcon(@"V:|-36-[_title]-1-[link]");
    vcon(@"V:|-110-[_login]-(20)-[shortcutLabel]-(3)-[shortcutView(25)]-(20)-[copyright]-m-|");
    vcon(@"H:|-m-[_login]-(>=m)-|");
    vcon(@"H:|-(>=m)-[shortcutLabel]-(>=m)-|");
    vcon(@"H:|-m-[shortcutView(>=220)]-(m)-|");
    vcon(@"H:|-(>=m)-[copyright]-(>=m)-|");
    
    // Leading-align title, link
    [v addConstraint:[NSLayoutConstraint constraintWithItem:_title attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:link attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    
    // Center shortcutLabel
    [v addConstraint:[NSLayoutConstraint constraintWithItem:shortcutLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    // Center copyright
    [v addConstraint:[NSLayoutConstraint constraintWithItem:copyright attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    
    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    _login.state = [self isLoginItemEnabled] ? NSOnState : NSOffState;
}

#pragma mark -
#pragma mark Toggle title

- (void)toggleTitle:(id)sender
{
    static BOOL toggle = NO;
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *version = toggle ? @"CFBundleShortVersionString": @"CFBundleVersion";
    NSString *str = [NSString stringWithFormat:@"Itsycal %@", infoDict[version]];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:str];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, 7)];
    _title.attributedStringValue = s;
    toggle = !toggle;
}

#pragma mark -
#pragma mark Login item

- (void)launchAtLogin:(NSButton *)login
{
    [self enableLoginItem:login.state == NSOnState ? YES : NO];
}

- (BOOL)isLoginItemEnabled
{
    BOOL isEnabled = NO;
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef) {
        UInt32 seedValue;
        NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
        for (id item in loginItems) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
            if (pathURL && [pathURL.path hasPrefix:appPath]) {
                isEnabled = YES;
                break;
            }
        }
        CFRelease(loginItemsRef);
    }
    return isEnabled;
}

- (void)enableLoginItem:(BOOL)enable;
{
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef) {
        if (enable) {
            // We call LSSharedFileListInsertItemURL to insert the item at the bottom of Login Items list.
            CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
            if (item != NULL) CFRelease(item);
        }
        else {
            // Grab the contents of the shared file list (LSSharedFileListItemRef objects)
            // and pop it in an array so we can iterate through it to find our item.
            UInt32 seedValue;
            NSArray *loginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemsRef, &seedValue));
            for (id item in loginItems) {
                LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
                NSURL *pathURL = CFBridgingRelease(LSSharedFileListItemCopyResolvedURL(itemRef, 0, NULL));
                if (pathURL && [pathURL.path hasPrefix:appPath]) {
                    LSSharedFileListItemRemove(loginItemsRef, itemRef); // Deleting the item
                }
            }
        }
        CFRelease(loginItemsRef);
    }
}

@end
