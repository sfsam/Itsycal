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

    // The content goes in a box that hugs it. The box is centered
    // so the content stays centered when the Settings window is
    // wider than the content (see PrefsVC).
    NSView *box = [NSView new];
    [v addSubview:box];

    // Convenience function for making labels.
    MoTextField* (^label)(NSString*, BOOL) = ^MoTextField* (NSString *stringValue, BOOL isLink) {
        MoTextField *txt = [MoTextField labelWithString:stringValue];
        if (isLink) {
            txt.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
            txt.linkEnabled = YES;
        }
        [box addSubview:txt];
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

    NSTextField *emojiHelp    = label(@"🛟", NO);
    NSTextField *emojiTwitter = label(@"🙅‍♂️", NO);
    NSTextField *emojiDonate  = label(@"♥️", NO);

    // The emoji are decorative, so VoiceOver skips them.
    [emojiHelp.cell setAccessibilityElement:NO];
    [emojiTwitter.cell setAccessibilityElement:NO];
    [emojiDonate.cell setAccessibilityElement:NO];

    NSTextField *copyright1 = label(@"© 2012—2026", NO);
    MoTextField *copyright2 = label(@"mowglii.com", YES);

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:box metrics:@{@"m": @25} views:NSDictionaryOfVariableBindings(appName, version, help, emojiHelp, follow, emojiTwitter, donate, emojiDonate, copyright1, copyright2)];
    [vfl :@"V:|[appName]-m-[help]-10-[follow]-10-[donate]-m-[copyright1]|"];
    [vfl :@"H:|[appName]-4-[version]-(>=0)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|[emojiHelp]-6-[help]-(>=0)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|[emojiTwitter]-6-[follow]-(>=0)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|[emojiDonate]-6-[donate]-(>=0)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|[copyright1]-4-[copyright2]-(>=0)-|" :NSLayoutFormatAlignAllBaseline];

    MoVFLHelper *outer = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @25} views:NSDictionaryOfVariableBindings(box)];
    [outer :@"V:|-m-[box]-m-|"];
    [outer :@"H:|-(>=m)-[box]-(>=m)-|"];
    [box.centerXAnchor constraintEqualToAnchor:v.centerXAnchor].active = YES;

    // Make the box as narrow as its content allows.
    NSLayoutConstraint *hug = [box.widthAnchor constraintEqualToConstant:0];
    hug.priority = 1;
    hug.active = YES;

    self.view = v;
}

@end
