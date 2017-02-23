//
//  MoCalGrid.m
//
//
//  Created by Sanjay Madan on 12/3/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "MoCalGrid.h"
#import "MoCalCell.h"

@implementation MoCalGrid
{
    NSUInteger _rows, _cols, _hMargin, _vMargin;
}

- (instancetype)initWithRows:(NSUInteger)rows columns:(NSUInteger)cols horizontalMargin:(NSUInteger)hMargin verticalMargin:(NSUInteger)vMargin
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        NSMutableArray *cells = [NSMutableArray new];
        for (NSUInteger row = 0; row < rows; row++) {
            for (NSUInteger col = 0; col < cols; col++) {
                CGFloat x = kMoCalCellWidth * col + hMargin;
                CGFloat y = kMoCalCellHeight * rows - kMoCalCellHeight * (row + 1) + vMargin;
                MoCalCell *cell = [MoCalCell new];
                [cell setFrame:NSMakeRect(x, y, kMoCalCellWidth, kMoCalCellHeight)];
                [self addSubview:cell];
                [cells addObject:cell];
            }
        }
        _cells = [NSArray arrayWithArray:cells];
        _rows  = rows;
        _cols  = cols;
        _hMargin = hMargin;
        _vMargin = vMargin;
        
        // We will auto layout this view
        [self setTranslatesAutoresizingMaskIntoConstraints:NO];

        // Hug the cells tightly
        [self setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
        [self setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    }
    return self;
}

- (void)addRow
{
    NSMutableArray *cells = [_cells mutableCopy];

    // Shift existing cells up.
    for (MoCalCell *cell in cells) {
        NSRect frame = cell.frame;
        frame.origin.y += kMoCalCellHeight;
        cell.frame = frame;
    }

    // Add new row of cells.
    for (NSUInteger col = 0; col < _cols; col++) {
        CGFloat x = kMoCalCellWidth * col + _hMargin;
        CGFloat y = kMoCalCellHeight * (_rows + 1) - kMoCalCellHeight * (_rows + 1) + _vMargin;
        MoCalCell *cell = [MoCalCell new];
        [cell setFrame:NSMakeRect(x, y, kMoCalCellWidth, kMoCalCellHeight)];
        [self addSubview:cell];
        [cells addObject:cell];
    }

    _rows += 1;
    _cells = [NSArray arrayWithArray:cells];
    [self invalidateIntrinsicContentSize];
}

- (void)removeRow
{
    NSMutableArray *cells = [_cells mutableCopy];

    // Remove last row of cells.
    for (NSUInteger col = 0; col < _cols; col++) {
        MoCalCell *cell = [cells lastObject];
        [cell removeFromSuperview];
        [cells removeLastObject];
    }

    // Shift remaining cells down.
    for (MoCalCell *cell in cells) {
        NSRect frame = cell.frame;
        frame.origin.y -= kMoCalCellHeight;
        cell.frame = frame;
    }

    _rows -= 1;
    _cells = [NSArray arrayWithArray:cells];
    [self invalidateIntrinsicContentSize];
}

- (MoCalCell *)cellAtPoint:(NSPoint)point
{
    NSInteger col = floorf((point.x - _hMargin) / kMoCalCellWidth);
    NSInteger row = floorf((point.y - _vMargin) / kMoCalCellHeight);
    row = _rows - row - 1; // flip row coordinate
    if (col < 0 || row < 0 || col >= _cols || row >= _rows) {
        return nil;
    }
    return _cells[_cols * row + col];
}

- (MoCalCell *)cellWithDate:(MoDate)date;
{
    for (MoCalCell *cell in self.cells) {
        if (CompareDates(date, cell.date) == 0) {
            return cell;
        }
    }
    return nil;
}

- (NSRect)cellsRect
{
    return NSInsetRect(self.bounds, _hMargin, _vMargin);
}

- (NSSize)intrinsicContentSize
{
    CGFloat width  = kMoCalCellWidth  * _cols + 2 * _hMargin;
    CGFloat height = kMoCalCellHeight * _rows + 2 * _vMargin;
    return NSMakeSize(width, height);
}

@end
