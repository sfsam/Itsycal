//
//  Created by Sanjay Madan on 10/28/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EventInfo;

@interface AgendaPopoverVC : NSViewController
@property (nonatomic, weak) NSCalendar *nsCal;
@property (nonatomic) NSButton *btnDelete;
- (void)populateWithEventInfo:(EventInfo *)info;
- (void)scrollToTopAndFlashScrollers;
- (NSSize)size;
@end
