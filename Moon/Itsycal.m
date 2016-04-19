//
//  Itsycal.m
//  Itsycal
//
//  Created by Sanjay Madan on 2/3/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "Itsycal.h"

// Bundle IDs
NSString * const kItsycalBundleID = @"com.mowglii.ItsycalApp";
NSString * const kItsycalExtraBundleID = @"com.mowglii.ItsycalExtra";

// NSUserDefaults keys
NSString * const kPinItsycal = @"PinItsycal";
NSString * const kShowEventDays = @"ShowEventDays";
NSString * const kShowWeeks = @"ShowWeeks";
NSString * const kWeekStartDOW = @"WeekStartDOW";
NSString * const kKeyboardShortcut = @"KeyboardShortcut";
NSString * const kHighlightWeekend = @"HighlightWeekend";
NSString * const kShowMonthInIcon = @"ShowMonthInIcon";
NSString * const kShowDayOfWeekInIcon = @"ShowDayOfWeekInIcon";

// Preferences notifications
NSString * const kDaysToShowPreferenceChanged = @"DaysToShowPreferenceChanged";
NSString * const kShowMonthInIconPreferenceChanged = @"ShowMonthInIconPreferenceChanged";
NSString * const kShowDayOfWeekInIconPreferenceChanged = @"ShowDayOfWeekInIconPreferenceChanged";

// Menu extra notifications
NSString * const ItsycalIsActiveNotification = @"ItsycalIsActiveNotification";
NSString * const ItsycalDidUpdateIconNotification = @"ItsycalDidUpdateIconNotification";
NSString * const ItsycalKeyboardShortcutNotification = @"ItsycalKeyboardShortcutNotification";
NSString * const ItsycalExtraIsActiveNotification = @"ItsycalMenuExtraIsActiveNotification";
NSString * const ItsycalExtraClickedNotification = @"ItsycalMenuExtraClickedNotification";
NSString * const ItsycalExtraDidMoveNotification = @"ItsycalMenuExtraDidMoveNotification";
NSString * const ItsycalExtraWillUnloadNotification = @"ItsycalMenuExtraWillUnloadNotification";

// Based on cocoawithlove.com/2009/09/creating-alpha-masks-from-text-on.html
NSImage *ItsycalIconImageForText(NSString *text)
{
    if (text == nil) text = @"!";
    
    // Measure text width
    NSFont *font = [NSFont boldSystemFontOfSize:11.5];
    CGRect textRect = [[[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: font}] boundingRectWithSize:CGSizeMake(999, 999) options:0 context:nil];

    // Icon width is at least 19 pts with 4 pt margins
    CGFloat width = MAX(4 + ceilf(NSWidth(textRect)) + 4, 19);
    CGFloat height = 16;
    NSImage *image = [NSImage imageWithSize:NSMakeSize(width, height) flipped:NO drawingHandler:^BOOL (NSRect rect) {
        
        // Get image's context and figure out scale.
        CGContextRef const ctx = [[NSGraphicsContext currentContext] graphicsPort];
        NSRect deviceRect = CGContextConvertRectToDeviceSpace(ctx, rect);
        CGFloat scale  = NSHeight(deviceRect)/NSHeight(rect);
        CGFloat width  = scale * NSWidth(rect);
        CGFloat height = scale * NSHeight(rect);
        
        // Create a grayscale context for the mask
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
        CGContextRef maskContext = CGBitmapContextCreate(NULL, width, height, 8, 0, colorspace, 0);
        CGColorSpaceRelease(colorspace);
        
        // Switch to the context for drawing.
        // Drawing done in this context is scaled.
        NSGraphicsContext *maskGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:maskContext flipped:NO];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:maskGraphicsContext];
        
        // Draw a white rounded rect background into the mask context
        CGFloat radius = scale * 2;
        [[NSColor whiteColor] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:deviceRect xRadius:radius yRadius:radius] fill];
        
        // Draw centered black text into the mask context
        NSMutableParagraphStyle *pstyle = [NSMutableParagraphStyle new];
        pstyle.alignment = NSCenterTextAlignment;
        
        // Adjust baseline and set font. Font size is slightly bigger
        // when scale > 1 because it looks better that way.
        NSRect textRect = NSOffsetRect(deviceRect, 0, scale * -1);
        NSFont *font = [NSFont boldSystemFontOfSize:(scale > 1) ? 24 : 11.5];

        [text drawInRect:textRect withAttributes:@{NSFontAttributeName: font, NSParagraphStyleAttributeName: pstyle, NSForegroundColorAttributeName: [NSColor blackColor]}];
        
        // Switch back to the image's context.
        [NSGraphicsContext restoreGraphicsState];
        
        // Create an image mask from our mask context.
        CGImageRef alphaMask = CGBitmapContextCreateImage(maskContext);
        
        // Fill the image, clipped by the mask.
        CGContextClipToMask(ctx, rect, alphaMask);
        [[NSColor blackColor] set];
        NSRectFill(rect);
        
        CGImageRelease(alphaMask);
        
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

BOOL OSVersionIsAtLeast(NSInteger majorVersion, NSInteger minorVersion, NSInteger patchVersion)
{
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    return (os.majorVersion >  majorVersion) ||
           (os.majorVersion == majorVersion && os.minorVersion >  minorVersion) ||
           (os.majorVersion == majorVersion && os.minorVersion == minorVersion && os.patchVersion >= patchVersion) ? YES : NO;
}
