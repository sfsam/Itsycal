//
//  MoTextField.m
//  
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "MoTextField.h"

@interface MoTextField ()
- (void)openLink;
@end

// VoiceOver sees the cell, not the text field, so the
// cell reports links and opens them when pressed.
@interface MoTextFieldCell : NSTextFieldCell
@end

@implementation MoTextFieldCell

- (NSAccessibilityRole)accessibilityRole
{
    MoTextField *field = (MoTextField *)self.controlView;
    return field.linkEnabled ? NSAccessibilityLinkRole : [super accessibilityRole];
}

- (NSString *)accessibilityLabel
{
    MoTextField *field = (MoTextField *)self.controlView;
    return field.linkEnabled ? field.stringValue : [super accessibilityLabel];
}

- (BOOL)isAccessibilitySelectorAllowed:(SEL)selector
{
    // Only links can be pressed.
    if (selector == @selector(accessibilityPerformPress)) {
        return ((MoTextField *)self.controlView).linkEnabled;
    }
    return [super isAccessibilitySelectorAllowed:selector];
}

- (BOOL)accessibilityPerformPress
{
    [(MoTextField *)self.controlView openLink];
    return YES;
}

@end

@implementation MoTextField
{
    NSColor *_originalColor;
}

+ (Class)cellClass
{
    return [MoTextFieldCell class];
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _linkColor = [NSColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1];
        _originalColor = self.textColor;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _linkColor = [NSColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1];
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
            [self openLink];
        }
    }
    else {
        if (self.target && self.action) {
            [self sendAction:self.action to:self.target];
        }
        [super mouseUp:theEvent];
    }
}

- (void)openLink
{
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

@end
