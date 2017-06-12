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
            return [NSColor colorWithRed:0.51 green:0.51 blue:0.51 alpha:1];
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
            return [NSColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1];
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
            return [NSColor colorWithWhite:0 alpha:0.25];
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
            return [NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1];
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
            return [NSColor colorWithRed:0.2 green:0.2 blue:0.3 alpha:0.2];
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
            return [NSColor colorWithWhite:0 alpha:0.2];
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
            return [NSAppearance appearanceNamed:@"NSAppearanceNameAqua"];
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
