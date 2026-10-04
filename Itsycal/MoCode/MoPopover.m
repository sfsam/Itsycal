//
//  Created by Sanjay Madan on 10/3/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import "MoPopover.h"

static void *kAppearanceContext = &kAppearanceContext;

@implementation MoPopover

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.appearance = NSApp.effectiveAppearance;
        [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:kAppearanceContext];
    }
    return self;
}

- (void)dealloc
{
    [NSApp removeObserver:self forKeyPath:@"effectiveAppearance" context:kAppearanceContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context == kAppearanceContext) {
        self.appearance = NSApp.effectiveAppearance;
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
