//
//  Created by Sanjay Madan on 2/23/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "MoCalResizeHandle.h"
#import "MoVFLHelper.h"
#import "Themer.h"

@implementation MoCalResizeHandle
{
    NSBox *_bkg;
    NSBox *_handle;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    NSBox* (^box)(NSColor *) = ^NSBox* (NSColor *color) {
        NSBox *bx = [NSBox new];
        bx.boxType = NSBoxCustom;
        bx.borderType = NSNoBorder;
        bx.cornerRadius = 2;
        bx.fillColor = color;
        [self addSubview:bx];
        return bx;
    };
    
    self = [super initWithFrame:frameRect];
    if (self) {
        _bkg = box(Theme.resizeHandleBackgroundColor);
        _handle = box(Theme.resizeHandleForegroundColor);
        
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:self metrics:nil views:NSDictionaryOfVariableBindings(_bkg, _handle)];
        [vfl :@"V:|[_bkg]|"];
        [vfl :@"H:|-3-[_bkg]-3-|"];
        
        [_handle.widthAnchor constraintEqualToConstant:24].active = YES;
        [_handle.heightAnchor constraintEqualToConstant:4].active = YES;
        [_handle.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
        [_handle.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

- (void)dim:(BOOL)shouldDim
{
    _bkg.animator.alphaValue = shouldDim ? 0 : 1;
    _handle.animator.alphaValue = shouldDim ? 0.1 : 1;
}

@end
