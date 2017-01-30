//
//  Created by Sanjay Madan on 1/29/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EventCenter;

@interface PrefsVC : NSViewController <NSToolbarDelegate>

@property (nonatomic, weak) EventCenter *ec;

@end
