//
//  MoUtils.m
//  
//
//  Created by Sanjay Madan on 10/31/16.
//  Copyright © 2016 mowglii.com. All rights reserved.
//

#import "MoUtils.h"

BOOL OSVersionIsAtLeast(NSInteger majorVersion, NSInteger minorVersion, NSInteger patchVersion)
{
    NSOperatingSystemVersion v = {majorVersion, minorVersion, patchVersion};
    return [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:v];
}
