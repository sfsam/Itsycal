//
//  IconIsConfigurableTransformer.m
//  Itsycal
//
//  Created by Sanjay Madan on 9/17/23.
//  Copyright © 2023 mowglii.com. All rights reserved.
//

#import "IconIsConfigurableTransformer.h"

@implementation IconIsConfigurableTransformer

+ (Class)transformedValueClass
{
    return [NSNumber class];
}

- (id)transformedValue:(id)value
{
    NSInteger index;

    // By default, icon is configurable.
    if (value == nil) return [NSNumber numberWithBool:YES];
 
    if ([value respondsToSelector:@selector(integerValue)]) {
        index = [value integerValue];
    }
    else {
        [NSException raise:NSInternalInconsistencyException format:@"IconIsConfigurableTransformer: value (%@) does not respond to -integerValue.", [value class]];
    }
 
    // kMenuBarIconType is 0, 1, 2 or 3.
    // Both type 0 (solid round rect) and type 1 (outlined round rect) can be
    // configured to show month and day of week. Types 2 and 3 cannot.
    return [NSNumber numberWithBool: index <= 1];
}

@end
