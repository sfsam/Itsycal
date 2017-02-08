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
            txt.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
            txt.linkEnabled = YES;
        }
        [v addSubview:txt];
        return txt;
    };

    // App name and version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    MoTextField *appName = label([NSString stringWithFormat:@"Itsycal %@", infoDict[@"CFBundleShortVersionString"]], NO);
    appName.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    appName.textColor = [NSColor grayColor];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:appName.stringValue];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, 7)];
    appName.attributedStringValue = s;

    // Links
    MoTextField *appLink = label(@"mowglii.com", YES);
    appLink.urlString = @"https://mowglii.com";

    MoTextField *twtrLink = label(@"@mowgliiapps", YES);
    twtrLink.urlString = @"https://twitter.com/intent/follow?screen_name=mowgliiapps";

    MoTextField *sparkleLink = label(@"Sparkle", YES);
    sparkleLink.urlString = @"https://github.com/sparkle-project/Sparkle";

    MoTextField *masshortcutLink = label(@"MASShortcut", YES);
    masshortcutLink.urlString = @"https://github.com/shpakovski/MASShortcut";

    MoTextField *varelaLink = label(@"Varela Round", YES);
    varelaLink.urlString = @"https://github.com/alefalefalef/Varela-Round-Hebrew";

    // Labels
    MoTextField *web = label(@"web:", NO);

    MoTextField *twitter = label(@"twitter:", NO);

    MoTextField *smile = label(@"(๑˃̵ᴗ˂̵)و", NO);
    smile.font = [NSFont systemFontOfSize:16 weight:NSFontWeightLight];

    MoTextField *sparkleCopyright = label(@"Copyright © 2006 Andy Matuschak", NO);
    sparkleCopyright.font = [NSFont systemFontOfSize:11];

    MoTextField *masshortcutCopyright = label(@"Copyright © 2013 Vadim Shpakovski", NO);
    masshortcutCopyright.font = [NSFont systemFontOfSize:11];

    MoTextField *varelaCopyright = label(@"Copyright © 2016 Varela Round Authors", NO);
    varelaCopyright.font = [NSFont systemFontOfSize:11];

    MoTextField *copyright = label(infoDict[@"NSHumanReadableCopyright"], NO);

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appName, appLink, twtrLink, web, twitter, varelaLink, varelaCopyright, sparkleLink, sparkleCopyright, masshortcutLink, masshortcutCopyright, smile, copyright)];
    [vfl :@"V:|-m-[appName]-[appLink]-[twtrLink]-30-[varelaLink][varelaCopyright]-[sparkleLink][sparkleCopyright]-[masshortcutLink][masshortcutCopyright]-18-[smile]-20-[copyright]-m-|"];
    [vfl :@"H:|-m-[appName]-(>=m)-|"];
    [vfl :@"H:[web]-[appLink]-(>=m)-|" : NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[twitter]-[twtrLink]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[sparkleLink]-(>=m)-|"];
    [vfl :@"H:|-m-[sparkleCopyright]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcutLink]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcutCopyright]-(>=m)-|"];
    [vfl :@"H:|-m-[varelaLink]-(>=m)-|"];
    [vfl :@"H:|-m-[varelaCopyright]-(>=m)-|"];
    [vfl :@"H:|-(>=m)-[smile]-(>=m)-|"];
    [vfl :@"H:|-m-[copyright]-(>=m)-|"];

    // Align web: and twitter: by trailing attribute
    [v addConstraint:[NSLayoutConstraint constraintWithItem:web attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:twitter attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];

    // Center smile
    [v addConstraint:[NSLayoutConstraint constraintWithItem:smile attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    self.view = v;
}

@end
