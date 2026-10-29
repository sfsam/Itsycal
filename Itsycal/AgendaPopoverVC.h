//
//  Created by Sanjay Madan on 10/28/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EventInfo;

@interface AgendaPopoverVC : NSViewController
// Called when the user clicks the delete button or presses delete.
// The button only shows for an event whose calendar can be changed.
@property (nonatomic, copy) void (^deleteHandler)(void);
- (void)populateWithEventInfo:(EventInfo *)info;
// Call once the popover is shown at its final size.
- (void)popoverDidShow;
- (NSSize)size;
@end
