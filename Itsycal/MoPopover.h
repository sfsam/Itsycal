//
//  Created by Sanjay Madan on 10/3/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// A popover that uses the app's appearance and keeps it up to
// date while the popover is shown.
//
// Left to itself, a popover uses a vibrant appearance, which
// draws text and controls differently. So we set the app's
// (non-vibrant) appearance explicitly, and set it again whenever
// the app's appearance changes, for example when the user changes
// the theme or the system switches between light and dark.

@interface MoPopover : NSPopover

@end
