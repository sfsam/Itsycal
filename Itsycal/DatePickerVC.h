//
//  Created by Sanjay Madan on 1/9/24.
//  Copyright © 2024 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoCalendar.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatePickerVC : NSViewController

@property (nonatomic, weak) NSPopover *enclosingPopover;

- (instancetype)initWithMoCal:(MoCalendar *)moCal nsCal:(NSCalendar *)nsCal;

@end

NS_ASSUME_NONNULL_END
