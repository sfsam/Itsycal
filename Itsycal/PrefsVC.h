//
//  Created by Sanjay Madan on 1/29/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PrefsVC : NSViewController <NSToolbarDelegate>

// Show About panel.
- (void)showAbout;

// Show General panel if About panel is showing.
- (void)showPrefs;

@end
