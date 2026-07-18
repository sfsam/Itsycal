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

    MoTextField *help = label(NSLocalizedString(@"Help", nil), YES);
    help.urlString = @"https://www.mowglii.com/itsycal/help.html";

    MoTextField *follow = label(NSLocalizedString(@"Follow", nil), YES);
    follow.urlString = @"https://twitter.com/intent/follow?screen_name=mowgliiapps";

    MoTextField *donate = label(NSLocalizedString(@"Donate", nil), YES);
    donate.urlString = @"https://mowglii.com/donate/";

    NSTextField *smile = label(@"(๑˃̵ᴗ˂̵)و", NO);
    smile.font = [NSFont systemFontOfSize:16 weight:NSFontWeightLight];

    NSTextField *emojiHelp    = label(@"🛟", NO);
    NSTextField *emojiTwitter = label(@"🙅‍♂️", NO);
    NSTextField *emojiDonate  = label(@"♥️", NO);

    NSTextField *copyright1 = label(@"© 2012—2025", NO);
    MoTextField *copyright2 = label(@"mowglii.com", YES);

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @25} views:NSDictionaryOfVariableBindings(appName, version, help, emojiHelp, follow, emojiTwitter, donate, emojiDonate, smile, copyright1, copyright2)];
    [vfl :@"V:|-m-[appName]-m-[help]-10-[follow]-10-[donate]-m-[smile]-m-[copyright1]-m-|"];
    [vfl :@"H:|-m-[appName]-4-[version]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[emojiHelp]-6-[help]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[emojiTwitter]-6-[follow]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[emojiDonate]-6-[donate]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[copyright1]-4-[copyright2]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    
    [smile.centerXAnchor constraintEqualToAnchor:v.centerXAnchor].active = YES;

    self.view = v;
}

@end
