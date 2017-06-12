//
//  ItsyColors.h
//  Itsycal
//
//  Created by Ale on 11/06/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "Itsycal.h"

@interface ItsyColors : NSObject

typedef NS_OPTIONS(NSInteger, ItsyThemes){
    TDefault = 0,
    TLight = 1,
    TDark = 2
};

+ (NSColor *) getPrimaryTextColor;
+ (NSColor *) getSecondaryTextColor;
+ (NSColor *) getPrimaryBackgroundColor;
+ (NSColor *) getSecondaryBackgroundColor;
+ (NSColor *) getBorderColor;
+ (NSColor *) getHighlightColor;
+ (NSColor *) getHoverColor;
+ (NSColor *) getShadowColor;

+ (NSAppearance *) getAppearance;
+ (BOOL)allowsVibrancy;

@end
