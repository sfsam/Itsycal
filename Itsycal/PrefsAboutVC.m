//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAboutVC.h"
#import "Itsycal.h"
#import "MoView.h"
#import "MoTextField.h"

@implementation PrefsAboutVC

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    MoView *v = [MoView new];

    v.translatesAutoresizingMaskIntoConstraints = YES;

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

    // Convenience function to make visual constraints.
    void (^vcon)(NSString*) = ^(NSString *format) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appName, appLink, twtrLink, acknowledgments, sparkleLink, sparkleCopyright, masshortcutLink, masshortcutCopyright, copyright)]];
    };
    vcon(@"V:|-m-[appName]-[appLink]-[twtrLink]-30-[acknowledgments]-[sparkleLink][sparkleCopyright]-[masshortcutLink][masshortcutCopyright]-40-[copyright]-m-|");
    vcon(@"H:|-m-[appName]-(>=m)-|");
    vcon(@"H:|-m-[appLink]-(>=m)-|");
    vcon(@"H:|-m-[twtrLink]-(>=m)-|");
    vcon(@"H:|-m-[acknowledgments]-(>=m)-|");
    vcon(@"H:|-m-[sparkleLink]-(>=m)-|");
    vcon(@"H:|-m-[sparkleCopyright]-(>=m)-|");
    vcon(@"H:|-m-[masshortcutLink]-(>=m)-|");
    vcon(@"H:|-m-[masshortcutCopyright]-(>=m)-|");
    vcon(@"H:|-m-[copyright]-(>=m)-|");

    self.view = v;
}

@end
