//
//  Created by Sanjay Madan on 1/16/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoCalendar.h" // for DOWMask type


// A control for picking which columns to highlight
// in the calendar. Used in the Preferences panel.
//
// Highlight:  S  M  T  W  T  F  S
//            [x][ ][ ][ ][ ][ ][x]
//

@interface HighlightPicker : NSControl

// The day of the week on which the week starts.
// 0...6; 0=Sunday, 1=Monday,... 6=Saturday
// Control will draw its checkboxes in this order.
@property (nonatomic) NSInteger weekStartDOW;

// A bitmask of the days selected by the picker.
@property (nonatomic) DOWMask selectedDOWs;

@end

