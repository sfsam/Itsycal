//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAboutVC.h"
#import "Itsycal.h"
#import "MoTextField.h"
#import "MoVFLHelper.h"

@implementation PrefsAboutVC

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    NSView *v = [NSView new];

    // Convenience function for making labels.
    MoTextField* (^label)(NSString*, BOOL) = ^MoTextField* (NSString *stringValue, BOOL isLink) {
        MoTextField *txt = [MoTextField labelWithString:stringValue];
        txt.translatesAutoresizingMaskIntoConstraints = NO;
        if (isLink) {
            txt.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
            txt.linkEnabled = YES;
        }
        [v addSubview:txt];
        return txt;
    };

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSTextField *appName = label(@"Itsycal", NO);
    appName.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
    NSTextField *version = label([NSString stringWithFormat:@"%@ (%@)", infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]], NO);
    version.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    version.textColor = [NSColor secondaryLabelColor];
    NSTextField *donateWith = label(NSLocalizedString(@"Donate with", nil), NO);
    MoTextField *paypal = label(@"PayPal", YES);
    NSTextField *or = label(NSLocalizedString(@"or", nil), NO);
    MoTextField *square = label(@"Square", YES);
    NSTextField *emoji = label(@"♥️", NO);
    NSTextField *follow = label(NSLocalizedString(@"Follow", nil), NO);
    NSTextField *smile = label(@"(๑˃̵ᴗ˂̵)و", NO);
    smile.font = [NSFont systemFontOfSize:16 weight:NSFontWeightLight];
    MoTextField *mowgliiapps = label(@"@mowgliiapps", YES);
    MoTextField *sparkle = label(@"Sparkle", YES);
    MoTextField *sparkleCopyright = label(@"© 2006 Andy Matuschak", NO);
    MoTextField *masshortcut = label(@"MASShortcut", YES);
    MoTextField *masshortcutCopyright = label(@"© 2013 Vadim Shpakovski", NO);
    NSTextField *copyright1 = label(@"© 2012 − 2018", NO);
    MoTextField *copyright2 = label(@"mowglii.com", YES);

    paypal.urlString = @"https://www.paypal.me/mowgliiapps";
    square.urlString = @"https://cash.me/$Mowglii";
    mowgliiapps.urlString = @"https://twitter.com/intent/follow?screen_name=mowgliiapps";
    sparkle.urlString = @"https://github.com/sparkle-project/Sparkle";
    masshortcut.urlString = @"https://github.com/shpakovski/MASShortcut";

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @25} views:NSDictionaryOfVariableBindings(appName, version, donateWith, paypal, or, square, emoji, follow, smile, mowgliiapps, sparkle, sparkleCopyright, masshortcut, masshortcutCopyright, copyright1, copyright2)];
    [vfl :@"V:|-m-[appName]-8-[version]-m-[donateWith]-10-[follow]-18-[smile]-12-[sparkle][sparkleCopyright]-10-[masshortcut][masshortcutCopyright]-m-[copyright1]-m-|"];
    [vfl :@"H:|-m-[appName]-(>=m)-|"];
    [vfl :@"H:|-m-[version]-(>=m)-|"];
    [vfl :@"H:|-m-[donateWith]-4-[paypal]-4-[or]-4-[square]-6-[emoji]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[follow]-4-[mowgliiapps]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[sparkle]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcut]-(>=m)-|"];
    [vfl :@"H:|-m-[sparkleCopyright]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcutCopyright]-(>=m)-|"];
    [vfl :@"H:|-m-[copyright1]-4-[copyright2]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    
    [smile.centerXAnchor constraintEqualToAnchor:v.centerXAnchor].active = YES;

    self.view = v;
}

@end
