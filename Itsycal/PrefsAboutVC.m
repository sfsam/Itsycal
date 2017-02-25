//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAboutVC.h"
#import "Itsycal.h"
#import "MoView.h"
#import "MoTextField.h"
#import "MoVFLHelper.h"

@implementation PrefsAboutVC

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
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

    // App name and version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    MoTextField *appName = label([NSString stringWithFormat:@"Itsycal  %@", infoDict[@"CFBundleShortVersionString"]], NO);
    appName.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    appName.textColor = [NSColor grayColor];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:appName.stringValue];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor], NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightBold]} range:NSMakeRange(0, 7)];
    appName.attributedStringValue = s;

    // Links
    MoTextField *appLink = label(@"visit: mowglii.com", YES);
    appLink.urlString = @"https://mowglii.com";

    MoTextField *twtrLink = label(@"follow: @mowgliiapps", YES);
    twtrLink.urlString = @"https://twitter.com/intent/follow?screen_name=mowgliiapps";

    MoTextField *payPalLink = label(@"donate to: mowgliiapps", YES);
    payPalLink.urlString = @"https://mowglii.com/donate";

    MoTextField *sparkleLink = label(@"Sparkle", YES);
    sparkleLink.urlString = @"https://github.com/sparkle-project/Sparkle";

    MoTextField *masshortcutLink = label(@"MASShortcut", YES);
    masshortcutLink.urlString = @"https://github.com/shpakovski/MASShortcut";

    // Labels
    MoTextField *visit = label(@"🌎", NO);

    MoTextField *follow = label(@"🐦", NO);

    MoTextField *donate = label(@"♥️", NO);

    MoTextField *smile = label(@"(๑˃̵ᴗ˂̵)و", NO);
    smile.font = [NSFont systemFontOfSize:16 weight:NSFontWeightLight];

    MoTextField *sparkleCopyright = label(@"Copyright © 2006 Andy Matuschak", NO);
    sparkleCopyright.font = [NSFont systemFontOfSize:11];

    MoTextField *masshortcutCopyright = label(@"Copyright © 2013 Vadim Shpakovski", NO);
    masshortcutCopyright.font = [NSFont systemFontOfSize:11];

    MoTextField *copyright = label(infoDict[@"NSHumanReadableCopyright"], NO);

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appName, appLink, twtrLink, payPalLink, visit, follow, donate, sparkleLink, sparkleCopyright, masshortcutLink, masshortcutCopyright, smile, copyright)];
    [vfl :@"V:|-m-[appName]-[appLink]-[twtrLink]-[payPalLink]-18-[smile]-14-[sparkleLink][sparkleCopyright]-[masshortcutLink][masshortcutCopyright]-m-[copyright]-m-|"];
    [vfl :@"H:|-m-[appName]-(>=m)-|"];
    [vfl :@"H:|-m-[visit]-[appLink]-(>=m)-|" : NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[follow]-[twtrLink]-(>=m)-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[donate]-[payPalLink]-(>=m)-|" :NSLayoutFormatAlignAllCenterY];
    [vfl :@"H:|-m-[sparkleLink]-(>=m)-|"];
    [vfl :@"H:|-m-[sparkleCopyright]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcutLink]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcutCopyright]-(>=m)-|"];
    [vfl :@"H:|-(>=m)-[smile]-(>=m)-|" :NSLayoutFormatAlignAllTop];
    [vfl :@"H:|-m-[copyright]-(>=m)-|"];

    // Center smile
    [v addConstraint:[NSLayoutConstraint constraintWithItem:smile attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    self.view = v;
}

@end
