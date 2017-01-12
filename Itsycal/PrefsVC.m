//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsVC.h"

@implementation PrefsVC

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [super tabView:tabView didSelectTabViewItem:tabViewItem];

    // Resize the window to fit the selected tab's view.

    NSWindow *window = self.view.window;
    NSSize tabViewSize = tabViewItem.viewController.view.fittingSize;
    NSRect contentRect = (NSRect){0, 0, tabViewSize};
    NSRect contentFrame = [window frameRectForContentRect:contentRect];
    CGFloat windowHeightDelta = window.frame.size.height - contentFrame.size.height;
    NSPoint newOrigin = NSMakePoint(window.frame.origin.x, window.frame.origin.y + windowHeightDelta);
    NSRect newFrame = (NSRect){newOrigin, contentFrame.size};
    // Using the animator proxy seems to animate a lot better than
    // calling [window setFrame:newFrame display:NO animate:YES].
    [window.animator setFrame:newFrame display:NO];
}

@end
