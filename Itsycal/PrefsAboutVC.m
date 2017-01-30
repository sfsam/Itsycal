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
    MoTextField *appName = label([NSString stringWithFormat:@"Itsycal %@", infoDict[@"CFBundleShortVersionString"]], NO);
    appName.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    appName.textColor = [NSColor grayColor];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:appName.stringValue];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, 7)];
    appName.attributedStringValue = s;

    // Links
    MoTextField *appLink = label(@"web: mowglii.com", YES);
    appLink.urlString = @"https://mowglii.com";

    MoTextField *twtrLink = label(@"twtr: @mowgliiapps", YES);
    twtrLink.urlString = @"https://twitter.com/intent/follow?screen_name=mowgliiapps";

    MoTextField *sparkleLink = label(@"Sparkle", YES);
    sparkleLink.urlString = @"https://github.com/sparkle-project/Sparkle";

    MoTextField *masshortcutLink = label(@"MASShortcut", YES);
    masshortcutLink.urlString = @"https://github.com/shpakovski/MASShortcut";

    // Labels
    MoTextField *acknowledgments = label(@"Acknowledgments:", NO);
    MoTextField *sparkleCopyright = label(@"Copyright © 2006 Andy Matuschak", NO);
    sparkleCopyright.font = [NSFont systemFontOfSize:11];
    sparkleCopyright.textColor = [NSColor disabledControlTextColor];
    MoTextField *masshortcutCopyright = label(@"Copyright © 2013 Vadim Shpakovski", NO);
    masshortcutCopyright.font = [NSFont systemFontOfSize:11];
    masshortcutCopyright.textColor = [NSColor disabledControlTextColor];
    MoTextField *copyright = label(infoDict[@"NSHumanReadableCopyright"], NO);
    copyright.textColor = [NSColor disabledControlTextColor];

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appName, appLink, twtrLink, acknowledgments, sparkleLink, sparkleCopyright, masshortcutLink, masshortcutCopyright, copyright)];
    [vfl :@"V:|-m-[appName]-[appLink]-[twtrLink]-30-[acknowledgments]-[sparkleLink][sparkleCopyright]-[masshortcutLink][masshortcutCopyright]-40-[copyright]-m-|"];
    [vfl :@"H:|-m-[appName]-(>=m)-|"];
    [vfl :@"H:|-m-[appLink]-(>=m)-|"];
    [vfl :@"H:|-m-[twtrLink]-(>=m)-|"];
    [vfl :@"H:|-m-[acknowledgments]-(>=m)-|"];
    [vfl :@"H:|-m-[sparkleLink]-(>=m)-|"];
    [vfl :@"H:|-m-[sparkleCopyright]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcutLink]-(>=m)-|"];
    [vfl :@"H:|-m-[masshortcutCopyright]-(>=m)-|"];
    [vfl :@"H:|-m-[copyright]-(>=m)-|"];

    self.view = v;
}

@end
