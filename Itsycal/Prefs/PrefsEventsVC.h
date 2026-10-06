//
//  Created by Sanjay Madan on 10/5/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EventCenter;

@interface PrefsEventsVC : NSViewController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, weak) EventCenter *ec;

@end
