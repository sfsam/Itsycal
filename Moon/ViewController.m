//
//  ViewController.m
//  Moon
//
//  Created by Sanjay Madan on 2/4/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import "ViewController.h"
#import "MoCalendar.h"

@interface ViewController ()

@end

@implementation ViewController
{
    MoCalendar *_moCal;
    NSButton *_btnAdd, *_btnCal, *_btnOpt;
}

- (void)loadView
{
    NSLog(@"%s", __FUNCTION__);
    NSView *v = [NSView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    
    _moCal = [MoCalendar new];
    _moCal.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:_moCal];
    
    // Convenience function to config buttons.
    NSButton* (^btn)(NSString*, NSString*, SEL) = ^NSButton* (NSString *imageName, NSString *tip, SEL action) {
        NSButton *btn = [NSButton new];
        [btn setButtonType:NSMomentaryChangeButton];
        [btn setBordered:NO];
        [btn setImage:[NSImage imageNamed:imageName]];
        [btn setTarget:self];
        [btn setAction:action];
        [btn setToolTip:NSLocalizedString(tip, @"")];
        [btn setImagePosition:NSImageOnly];
        [btn setTranslatesAutoresizingMaskIntoConstraints:NO];
        [v addSubview:btn];
        return btn;
    };
    _btnOpt = btn(@"btnOpt", @"Options", @selector(foo:));
    _btnCal = btn(@"btnCal", @"Open Calendar...", @selector(foo:));
    _btnAdd = btn(@"btnAdd", @"New Event...", @selector(foo:));
    
    // Convenience function to make visual constraints.
    void (^vcon)(NSString*, NSLayoutFormatOptions) = ^(NSString *format, NSLayoutFormatOptions opts) {
        [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:opts metrics:nil views:NSDictionaryOfVariableBindings(_moCal, _btnAdd, _btnCal, _btnOpt)]];
    };
    vcon(@"H:|[_moCal]|", 0);
    vcon(@"V:|[_moCal]-(28)-|", 0);
    vcon(@"V:[_moCal]-(10)-[_btnOpt]", 0);
    vcon(@"H:|-(8)-[_btnAdd]-(>=0)-[_btnCal]-(12)-[_btnOpt]-(8)-|", NSLayoutFormatAlignAllCenterY);
    
    self.view = v;
}

- (void)foo:(id)sender
{
    NSLog(@"%@", [(NSButton *)sender toolTip]);
}

- (void)viewDidLoad {
    NSLog(@"%s", __FUNCTION__);
    [super viewDidLoad];
    // Do view setup here.
}

- (void)viewWillAppear
{
    NSLog(@"%s", __FUNCTION__);
    [super viewWillAppear];
    [self.view.window makeFirstResponder:_moCal];
}

- (void)viewDidAppear
{
    NSLog(@"%s", __FUNCTION__);
    [super viewDidAppear];
}

@end
