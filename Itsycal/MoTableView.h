//
//  MoTableView.h
//  
//
//  Created by Sanjay Madan on 2/21/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MoTableView;

@protocol MoTableViewDelegate <NSTableViewDelegate>

- (void)tableView:(nonnull MoTableView *)tableView didHoverOverRow:(NSInteger)row;

@end

@interface MoTableView : NSTableView

@property (nonatomic) BOOL enableHover;
@property (nonatomic, readonly) NSInteger hoverRow;
@property (nullable, weak) id<MoTableViewDelegate> delegate;

@end
