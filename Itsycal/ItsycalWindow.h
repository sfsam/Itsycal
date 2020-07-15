//
//  ItsycalWindow.h
//  Itsycal
//
//  Created by Sanjay Madan on 12/14/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ItsycalWindow : NSPanel

- (void)positionRelativeToRect:(NSRect)rect screenMaxX:(CGFloat)screenMaxX;

@end
