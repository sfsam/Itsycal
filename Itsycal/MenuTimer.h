//
//  MenuTimer.h
//  Itsycal
//
//  Created by Sanjay Madan on 11/4/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// A single countdown timer of 1 to 60 minutes, run from the status
// item's context menu. The menu bar shows nothing while it runs. The
// timer keeps counting while the Mac sleeps and isn't affected by
// changes to the clock. Its end time is saved so the timer survives a
// relaunch. When it ends, an alarm rings, unless it ended while the Mac
// was asleep or Itsycal wasn't running.
@interface MenuTimer : NSObject

// The items to put in the status item's context menu: a "Timer"
// section header, then a slider for choosing minutes and "Start:
// 12 min", or, while the timer runs, "Cancel: m:ss", which counts
// down while the menu is open.
- (NSArray<NSMenuItem *> *)menuItems;

// Call when the menu holding the items from -menuItems closes.
- (void)menuDidClose;

@end

NS_ASSUME_NONNULL_END
