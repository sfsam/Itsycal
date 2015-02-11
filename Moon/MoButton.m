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
    NSImage *_img, *_imgAlt;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
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
}

- (void)setAlternateImage:(NSImage *)alternateImage
{
    _imgAlt = alternateImage;
}

- (void)updateLayer
{
    // Animate state changes and highlighting by crossfading
    // between _img and _imgAlt.
    if (_imgAlt) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            context.allowsImplicitAnimation = YES;
            NSButtonCell *cell = self.cell;
            if (cell.showsStateBy) {
                if (!self.isHighlighted) {
                    self.layer.contents = self.state ? (id)_imgAlt : (id)_img;
                }
            }
            else {
                self.layer.contents = self.isHighlighted ? (id)_imgAlt : (id)_img;
            }
        } completionHandler:NULL];
    }
    else {
        self.layer.contents = (id)_img;
    }
}

@end
