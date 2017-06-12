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
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor blackColor];
            break;
        case TLight:
        case TDark:
            return [NSColor textColor];
            break;
    }
}

+ (NSColor *) getSecondaryTextColor{
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor grayColor];
            break;
        case TLight:
        case TDark:
            return [NSColor secondaryLabelColor];
            break;
    }
}

+ (NSColor *) getPrimaryBackgroundColor{
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor whiteColor];
            break;
        case TLight:
        case TDark:
            return [NSColor controlBackgroundColor];
            break;
    }
}

+ (NSColor *) getSecondaryBackgroundColor{
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor lightGrayColor];
            break;
        case TLight:
        case TDark:
            return [NSColor windowBackgroundColor];
            break;
    }
}

+ (NSColor *) getBorderColor{
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor blackColor];
            break;
        case TLight:
        case TDark:
            return [NSColor scrollBarColor];
            break;
    }
}

+ (NSColor *) getHighlightColor{
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor blueColor];
            break;
        case TLight:
        case TDark:
            return [NSColor alternateSelectedControlColor];
            break;
    }
}

+ (NSColor *) getHoverColor{
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor blueColor];
            break;
        case TLight:
        case TDark:
            return [NSColor alternateSelectedControlColor];
            break;
    }
}

+ (NSColor *) getShadowColor{
    switch ([self curTheme]) {
        case TDefault:
            return [NSColor blackColor];
            break;
        case TLight:
        case TDark:
            return [NSColor clearColor];
            break;
    }
}

+ (NSAppearance *) getAppearance{
    switch ([self curTheme]) {
        case TDefault:
            return nil;
            break;
        case TLight:
            return [NSAppearance appearanceNamed:@"NSAppearanceNameVibrantLight"];
            break;
        case TDark:
            return [NSAppearance appearanceNamed:@"NSAppearanceNameVibrantDark"];
            break;
    }
}

+ (BOOL)allowsVibrancy{
    switch ([self curTheme]) {
        case TDefault:
            return NO;
            break;
        case TLight:
        case TDark:
            return YES;
            break;
    }
}

+ (ItsyThemes) curTheme{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kThemeName];
}

@end
