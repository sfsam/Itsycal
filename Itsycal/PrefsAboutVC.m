//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAboutVC.h"
#import "Itsycal.h"
#import "MoTextField.h"
#import "MoVFLHelper.h"

@implementation PrefsAboutVC
{
    NSTextField *_emojiDonate;
}

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

    MoTextField *donate = label(NSLocalizedString(@"Donate", nil), YES);
    donate.urlString = @"https://www.mowglii.com/donate";

    MoTextField *follow = label(NSLocalizedString(@"Follow", nil), YES);
    follow.urlString = @"https://twitter.com/intent/follow?screen_name=mowgliiapps";

    NSTextField *smile = label(@"(๑˃̵ᴗ˂̵)و", NO);
    smile.font = [NSFont systemFontOfSize:16 weight:NSFontWeightLight];

    MoTextField *sparkle = label(@"Sparkle", YES);
    sparkle.urlString = @"https://github.com/sparkle-project/Sparkle";

    NSTextField *comma = label(NSLocalizedString(@",", nil), NO);

    MoTextField *masshortcut = label(@"MASShortcut", YES);
    masshortcut.urlString = @"https://github.com/shpakovski/MASShortcut";

    NSTextField *emojiHelp    = label(@"❓", NO);
    _emojiDonate              = label(@"☺️", NO);
    NSTextField *emojiTwitter = label(@"🐦", NO);
    NSTextField *emojiThanks  = label(@"🙏", NO);

    NSTextField *copyright1 = label(@"© 2012—2022", NO);
    MoTextField *copyright2 = label(@"mowglii.com", YES);

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @25} views:NSDictionaryOfVariableBindings(appName, version, help, emojiHelp, donate, _emojiDonate, follow, emojiTwitter, smile, emojiThanks, sparkle, comma, masshortcut, copyright1, copyright2)];
    [vfl :@"V:|-m-[appName]-m-[help]-10-[donate]-10-[follow]-10-[sparkle]-m-[smile]-m-[copyright1]-m-|"];
    [vfl :@"H:|-m-[appName]-4-[version]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[emojiHelp]-6-[help]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[_emojiDonate]-6-[donate]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[emojiTwitter]-6-[follow]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[emojiThanks]-6-[sparkle][comma]-4-[masshortcut]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    [vfl :@"H:|-m-[copyright1]-4-[copyright2]-(>=m)-|" :NSLayoutFormatAlignAllBaseline];
    
    [smile.centerXAnchor constraintEqualToAnchor:v.centerXAnchor].active = YES;

    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    static NSInteger index = 0;
    static NSArray *emojis = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        emojis = @[@"😊", @"😀", @"😜", @"😍",
                   @"😝", @"🤗", @"😘", @"✌️"];
    });
    _emojiDonate.stringValue = emojis[index];
    index = (index + 1) % emojis.count;
}

@end
