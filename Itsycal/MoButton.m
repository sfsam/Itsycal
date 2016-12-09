//
//  MoButton.m
//  
//
//  Created by Sanjay Madan on 2/11/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoButton.h"

@implementation MoButton
{
    NSImage *_img, *_imgAlt, *_imgDarkened;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.bordered = NO;
        self.imagePosition = NSImageOnly;
        self.wantsLayer = YES;
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawCrossfade;
    }
    return self;
}

- (BOOL)wantsUpdateLayer { return YES; }

- (CGSize)intrinsicContentSize
{
    return _img.size;
}

- (void)setImage:(NSImage *)image
{
    _img = image;
    // Create a 'darkened' version of the image. We will use
    // this as the alternate image if the user doesn't
    // provide one of their own.
    _imgDarkened = [NSImage imageWithSize:_img.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [_img drawInRect:dstRect];
        [[NSColor colorWithRed:0.4 green:0.6 blue:1 alpha:1] set];
        NSRectFillUsingOperation(dstRect, NSCompositingOperationSourceAtop);
        return YES;
    }];
}

- (void)setAlternateImage:(NSImage *)alternateImage
{
    _imgAlt = alternateImage;
}

- (void)updateLayer
{
    if (self.backgroundColor) {
        self.layer.backgroundColor = self.backgroundColor.CGColor;
    }
    
    // Animate state changes and highlighting by crossfading
    // between _img and img2. img2 is either the alternate
    // image, if the user provided one, or the darkened version
    // of _img we created.
    NSImage *img2 = _imgAlt ? _imgAlt : _imgDarkened;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        context.allowsImplicitAnimation = YES;
        // If this button reflects its state, use state to determine which img to use.
        if ([(NSButtonCell *)self.cell showsStateBy] != 0) {
            if (!self.isHighlighted) {
                self.layer.contents = self.state ? (id)img2 : (id)_img;
            }
        }
        // Otherwise, use highlight to determine which image to show.
        else {
            self.layer.contents = self.isHighlighted ? (id)img2 : (id)_img;
        }
    } completionHandler:NULL];
}

@end
