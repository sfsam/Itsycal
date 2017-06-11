//
//  ItsyColors.h
//  Itsycal
//
//  Created by Ale on 11/06/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface ItsyColors : NSObject

+ (NSColor *) getPrimaryTextColor;
+ (NSColor *) getSecondaryTextColor;
+ (NSColor *) getPrimaryBackgroundColor;
+ (NSColor *) getSecondaryBackgroundColor;
+ (NSColor *) getBorderColor;
+ (NSColor *) getHighlightColor;
+ (NSColor *) getHoverColor;
+ (NSColor *) getShadowColor;

+ (NSAppearance *) getAppearance;

@end
