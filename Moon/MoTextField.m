//
//  MoTextField.m
//  
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoTextField.h"

@implementation MoTextField
{
    NSColor *_originalColor;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _linkColor = [NSColor colorWithCalibratedRed:0.3f green:0.4f blue:0.8f alpha:1.f];
        _originalColor = self.textColor;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _linkColor = [NSColor colorWithCalibratedRed:0.3f green:0.4f blue:0.8f alpha:1.f];
        _originalColor = self.textColor;
    }
    return self;
}

- (void)setLinkEnabled:(BOOL)linkEnabled
{
    _linkEnabled = linkEnabled;
    if (_linkEnabled) {
        _originalColor = self.textColor;
        [super setTextColor:self.linkColor];
    }
    else {
        [super setTextColor:_originalColor];
    }
}

- (void)setTextColor:(NSColor *)textColor
{
    if (self.linkEnabled) {
        _originalColor = textColor;
    }
    else {
        [super setTextColor:textColor];
    }
}

- (void)setLinkColor:(NSColor *)linkColor
{
    _linkColor = linkColor;
    if (self.linkEnabled) {
        [super setTextColor:linkColor];
    }
}

- (void)resetCursorRects
{
    if (self.linkEnabled) {
        [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
    }
    else {
        [super resetCursorRects];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (self.linkEnabled) {
        NSPoint pointInWindow = [theEvent locationInWindow];
        NSPoint pointInView   = [self convertPoint:pointInWindow fromView:nil];
        if (NSPointInRect(pointInView, self.bounds)) {
            NSString *urlString = (self.urlString) ? self.urlString : self.stringValue;
            NSURL *url;
            if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
                url = [NSURL URLWithString:urlString];
            }
            else {
                url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlString]];
            }
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
    }
    else {
        [super mouseUp:theEvent];
    }
}

@end
