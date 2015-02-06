//
//  Itsycal.h
//  Itsycal2
//
//  Created by Sanjay Madan on 2/3/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MoDate.h"

MoDate Today(NSCalendar *cal);
NSImage *ItsycalDateIcon(int day, NSImage *datesImage);

