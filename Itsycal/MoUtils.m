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
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    return (os.majorVersion >  majorVersion) ||
    (os.majorVersion == majorVersion && os.minorVersion >  minorVersion) ||
    (os.majorVersion == majorVersion && os.minorVersion == minorVersion && os.patchVersion >= patchVersion) ? YES : NO;
}
