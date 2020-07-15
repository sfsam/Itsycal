//
//  Created by Sanjay Madan on 1/26/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "MoVFLHelper.h"

@implementation MoVFLHelper
{
    NSView *_superview;
    NSDictionary<NSString *, NSNumber *> *_metrics;
    NSDictionary<NSString *, id> *_views;
}

- (instancetype)initWithSuperview:(NSView *)superview metrics:(NSDictionary<NSString *, NSNumber *> *)metrics views:(NSDictionary<NSString *, id> *)views
{
    self = [super init];
    if (self) {
        _superview = superview;
        _metrics = metrics;
        _views = views;
        for (NSView *view in views.allValues) {
            view.translatesAutoresizingMaskIntoConstraints = NO;
        }
    }
    return self;
}

- (void):(NSString *)format
{
    [self :format :0];
}

- (void):(NSString *)format :(NSLayoutFormatOptions)options
{
    [_superview addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:options metrics:_metrics views:_views]];
}

@end
