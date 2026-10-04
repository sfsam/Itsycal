//
//  Created by Sanjay Madan on 1/26/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

// Make using Visual Format Language (VFL) nicer.

#import <Cocoa/Cocoa.h>

@interface MoVFLHelper : NSObject

- (instancetype)initWithSuperview:(NSView *)superview
                          metrics:(NSDictionary<NSString *, NSNumber *> *)metrics
                            views:(NSDictionary<NSString *, id> *)views;

// Create constraints with VFL format.
- (void):(NSString *)format;

// Create constraints with VFL format and options.
- (void):(NSString *)format :(NSLayoutFormatOptions)options;

@end
