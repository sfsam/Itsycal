//
//  Created by Sanjay Madan on 3/25/26.
//

// This code is adapted from Brent Simmons' NetNewsWire.
// It enables us to disable the menu icons introduced in macOS 26.
// If we want select menu items to have icons, we can enable them.
// MIT License
// https://github.com/Ranchero-Software/NetNewsWire

@import AppKit;

@interface NSMenuItem (NoImages)

/// When YES, the menu item’s image will be shown despite icon disabling.
/// Defaults to NO.
@property (nonatomic, assign) BOOL rs_shouldShowImage;

// Call +[NSMenuItem rs_disableImages] early (e.g. from AppDelegate init).
+ (void)rs_disableImages;

@end
