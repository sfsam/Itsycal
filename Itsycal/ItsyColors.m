//
//  ItsyColors.m
//  Itsycal
//
//  Created by Ale on 11/06/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "ItsyColors.h"

@implementation ItsyColors

+ (NSColor *) getPrimaryTextColor{
    return [NSColor textColor];
}

+ (NSColor *) getSecondaryTextColor{
    return [NSColor secondaryLabelColor];
}

+ (NSColor *) getPrimaryBackgroundColor{
    return [NSColor controlBackgroundColor];
}

+ (NSColor *) getSecondaryBackgroundColor{
    return [NSColor windowBackgroundColor];
}

+ (NSColor *) getBorderColor{
    return [NSColor scrollBarColor];
}

+ (NSColor *) getHighlightColor{
    return [NSColor alternateSelectedControlColor];
}

+ (NSColor *) getHoverColor{
    return [NSColor alternateSelectedControlTextColor];
}

+ (NSColor *) getShadowColor{
    return [NSColor clearColor];
}

+ (NSAppearance *) getAppearance{
    return [NSAppearance appearanceNamed:@"NSAppearanceNameVibrantDark"];
}

@end
