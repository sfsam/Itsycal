//
//  MoUtils.h
//
//
//  Created by Sanjay Madan on 10/31/16.
//  Copyright © 2016 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>

BOOL OSVersionIsAtLeast(NSInteger majorVersion, NSInteger minorVersion, NSInteger patchVersion);

/**
 * A clock that increments monotonically, tracking the time since an arbitrary
 * point, and will continue to increment while the system is asleep.
 * Use this instead of CACurrentMediaTime() to measure durations that might be
 * interrupted by the system going to sleep. CACurrentMediaTime() is also a
 * monotonic timer, but it stops counting when the CPU sleeps.
 */
NSTimeInterval MonotonicClockTime(void);
