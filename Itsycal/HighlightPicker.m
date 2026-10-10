//
//  Created by Sanjay Madan on 1/16/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "HighlightPicker.h"

@implementation HighlightPicker
{
    NSGridView *_grid;
    NSTextField *_label;
    NSArray<NSButton *> *_checkboxes;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _weekStartDOW = 0;
        _selectedDOWs = DOWMaskNone;

        // Make the _checkboxes array. Each checkbox has a
        // title that is the localized veryShortSymbol for a
        // day-of-the-week (dow). In English: S M T W T F S.
        NSDateFormatter *formatter = [NSDateFormatter new];
        NSArray *dows = [formatter veryShortWeekdaySymbols];
        NSArray *dowNames = [formatter standaloneWeekdaySymbols];
        NSMutableArray *checkboxes = [NSMutableArray new];
        for (NSInteger i = 0; i < 7; i++) {
            NSString *dow = [dows objectAtIndex:i];
            // Make French dow strings lowercase because that is the convention
            // in France. -veryShortWeekdaySymbols should have done this for us.
            if ([[NSLocale currentLocale].localeIdentifier hasPrefix:@"fr"]) {
                dow = [dow lowercaseString];
            }
            NSButton *checkbox = [NSButton checkboxWithTitle:dow target:self action:@selector(didClickCheckbox:)];
            checkbox.imagePosition = NSImageBelow;
            // VoiceOver reads the full day name since the
            // one-letter titles repeat (S M T W T F S).
            [checkbox.cell setAccessibilityLabel:[dowNames objectAtIndex:i]];
            [checkboxes addObject:checkbox];
        }
        _checkboxes = [NSArray arrayWithArray:checkboxes];

        // The _grid is a single row with the control's title (Highlight:)
        // and then seven checkboxes representing each day-of-the-week.
        _label = [NSTextField labelWithString:NSLocalizedString(@"Highlight:", @"")];
        _grid = [NSGridView gridViewWithViews:@[
            @[_label,
              _checkboxes[0], _checkboxes[1], _checkboxes[2], _checkboxes[3],
              _checkboxes[4], _checkboxes[5], _checkboxes[6]]]];
        _grid.rowAlignment = NSGridRowAlignmentFirstBaseline;
        _grid.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _grid.frame = self.bounds;
        [self addSubview:_grid];

        // Expose the checkboxes to VoiceOver as a group titled by the label.
        self.accessibilityElement = YES;
        self.accessibilityRole = NSAccessibilityGroupRole;
        self.accessibilityTitleUIElement = _label.cell;
    }
    return self;
}

- (NSArray *)accessibilityChildren
{
    // NSControl looks for accessibility children in its cell, and
    // this control has no cell, so list them here. Use the grid's
    // column order so VoiceOver reads the days as they are shown.
    NSMutableArray *children = [NSMutableArray new];
    for (NSInteger i = 0; i < _grid.numberOfColumns; i++) {
        [children addObject:[_grid cellAtColumnIndex:i rowIndex:0].contentView];
    }
    return NSAccessibilityUnignoredChildren(children);
}

- (void)setWeekStartDOW:(NSInteger)weekStartDOW
{
    // Constrain weekStartDOW to 0...6.
    weekStartDOW = MAX(MIN(weekStartDOW, 6), 0);

    // Reorder checkboxes in _grid so weekStartDOW is first.
    NSInteger diff = weekStartDOW - _weekStartDOW;
    if (diff > 0) {
        for (NSInteger i = 0; i < diff; i++) {
            [_grid moveColumnAtIndex:1 toIndex:7];
        }
    }
    else if (diff < 0) {
        for (NSInteger i = 0; i < -diff; i++) {
            [_grid moveColumnAtIndex:7 toIndex:1];
        }
    }
    _weekStartDOW = weekStartDOW;
}

- (void)setSelectedDOWs:(DOWMask)selectedDOWs
{
    // Turn on/off checkboxes to reflect selectedDOWs.
    for (NSInteger i = 0; i < 7; i++) {
        DOWMask test = 1 << i;
        [[_checkboxes objectAtIndex:i] setState:test & selectedDOWs];
    }
    _selectedDOWs = selectedDOWs;
}

- (void)didClickCheckbox:(NSButton *)checkbox
{
    // Set _selectedDOWs to reflect the states of the
    // checkboxes and then send action to the target.
    DOWMask newValue = DOWMaskNone;
    for (NSInteger i = 0; i < 7; i++) {
        if ([_checkboxes objectAtIndex:i].state == 1) {
            newValue |= (1 << i);
        }
    }
    _selectedDOWs = newValue;

    [self sendAction:self.action to:self.target];
}

@end
