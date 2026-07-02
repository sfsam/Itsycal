//
//  MoUtils.m
//  
//
//  Created by Sanjay Madan on 10/31/16.
//  Copyright © 2016 mowglii.com. All rights reserved.
//

#import <time.h>
#import "MoUtils.h"

NSTimeInterval MonotonicClockTime(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1.e-9;
}
