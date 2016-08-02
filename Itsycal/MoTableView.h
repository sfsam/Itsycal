//
//  MoTableView.h
//  
//
//  Created by Sanjay Madan on 2/21/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MoTableViewDelegate;

@interface MoTableView : NSTableView

@property (nonatomic) NSColor *hoverColor;
@property (nonatomic) BOOL enableHover;
@property (nonatomic, readonly) NSInteger hoverRow;
@property (nonatomic, weak) id<MoTableViewDelegate> delegate;

@end

@protocol MoTableViewDelegate <NSTableViewDelegate>

- (void)tableView:(MoTableView *)tableView didHoverOverRow:(NSInteger)row;

@end