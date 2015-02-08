//
//  MoTextField.h
//
//
//  Created by Sanjay Madan on 2/6/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MoTextField : NSTextField

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic) BOOL linkEnabled;
@property (nonatomic) NSColor *linkColor;

@end
