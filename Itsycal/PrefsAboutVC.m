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
    MoTextField* (^label)(NSString*) = ^MoTextField* (NSString *stringValue) {
        MoTextField *txt = [MoTextField labelWithString:stringValue];
        txt.translatesAutoresizingMaskIntoConstraints = NO;
        [v addSubview:txt];
        return txt;
    };

    // App name and version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    MoTextField *appName = label([NSString stringWithFormat:@"Itsycal %@", infoDict[@"CFBundleShortVersionString"]]);
    appName.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    appName.textColor = [NSColor disabledControlTextColor];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:appName.stringValue];
    [s addAttributes:@{NSForegroundColorAttributeName: [NSColor blackColor]} range:NSMakeRange(0, 7)];
    appName.attributedStringValue = s;

    // Mowglii link
    MoTextField *link  = label(@"mowglii.com/itsycal");
    link.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    link.linkEnabled = YES;

    // Copyright
    MoTextField *copyright = label(infoDict[@"NSHumanReadableCopyright"]);
    copyright.textColor = [NSColor disabledControlTextColor];

    // Convenience function to make visual constraints.
    void (^vcon)(NSString*) = ^(NSString *format) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(appName, link, copyright)]];
    };
    vcon(@"V:|-m-[appName]-[link]-m-[copyright]-m-|");
    vcon(@"H:|-m-[appName]-(>=m)-|");
    vcon(@"H:|-m-[link]-(>=m)-|");
    vcon(@"H:|-m-[copyright]-(>=m)-|");

    self.view = v;
}

@end
