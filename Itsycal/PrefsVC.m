//
//  Created by Sanjay Madan on 1/29/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsVC.h"

@implementation PrefsVC
{
    NSToolbar *_toolbar;
    NSMutableArray<NSString *> *_toolbarIdentifiers;
    NSInteger _selectedItemTag;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _toolbar = [[NSToolbar alloc] initWithIdentifier:@"Toolbar"];
        _toolbar.allowsUserCustomization = NO;
        _toolbar.delegate = self;
        _toolbarIdentifiers = [NSMutableArray new];
        _selectedItemTag = 0;
    }
    return self;
}

- (void)loadView
{
    self.view = [NSView new];
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    if (self.view.window.toolbar == nil) {
        self.view.window.toolbar = _toolbar;
        if (@available(macOS 11.0, *)) {
            self.view.window.toolbarStyle = NSWindowToolbarStylePreference;
        }
    }
}

- (void)showAbout
{
    NSString *identifier = NSLocalizedString(@"About", @"About prefs tab label");
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    item.tag = 2; // 2 == index of About panel
    _toolbar.selectedItemIdentifier = identifier;
    [self switchToTabForToolbarItem:item animated:NO];
}

- (void)showPrefs
{
    if (_selectedItemTag == 2) { // 2 == index of About panel
        NSString *identifier = NSLocalizedString(@"General", @"General prefs tab label");
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        item.tag = 0; // 0 == index of General panel.
        _toolbar.selectedItemIdentifier = identifier;
        [self switchToTabForToolbarItem:item animated:NO];
    }
}

- (void)setChildViewControllers:(NSArray<__kindof NSViewController *> *)childViewControllers
{
    [super setChildViewControllers:childViewControllers];
    for (NSViewController *childViewController in childViewControllers) {
        [_toolbarIdentifiers addObject:childViewController.title];
    }
    [self.view setFrame:(NSRect){0, 0, childViewControllers[0].view.fittingSize}];
    [childViewControllers[0].view setFrame:self.view.bounds];
    [self.view addSubview:childViewControllers[0].view];
    [_toolbar setSelectedItemIdentifier:_toolbarIdentifiers[0]];
}

- (void)toolbarItemClicked:(NSToolbarItem *)item
{
    [self switchToTabForToolbarItem:item animated:YES];
}

- (void)switchToTabForToolbarItem:(NSToolbarItem *)item animated:(BOOL)animated
{
    if (_selectedItemTag == item.tag) return;

    _selectedItemTag = item.tag;

    NSViewController *toVC = [self viewControllerForItemIdentifier:item.itemIdentifier];
    if (toVC) {

        if (self.view.subviews[0] == toVC.view) return;

        NSWindow *window = self.view.window;
        NSRect contentRect = (NSRect){0, 0, toVC.view.fittingSize};
        NSRect contentFrame = [window frameRectForContentRect:contentRect];
        CGFloat windowHeightDelta = window.frame.size.height - contentFrame.size.height;
        NSPoint newOrigin = NSMakePoint(window.frame.origin.x, window.frame.origin.y + windowHeightDelta);
        NSRect newFrame = (NSRect){newOrigin, contentFrame.size};

        [toVC.view setAlphaValue: 0];
        [toVC.view setFrame:contentRect];
        [self.view addSubview:toVC.view];

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            [context setDuration:animated ? 0.2 : 0];
            [window.animator setFrame:newFrame display:NO];
            [toVC.view.animator setAlphaValue:1];
            [self.view.subviews[0].animator setAlphaValue:0];
        } completionHandler:^{
            [self.view.subviews[0] removeFromSuperview];
        }];
    }
}

- (NSViewController *)viewControllerForItemIdentifier:(NSString *)itemIdentifier
{
    for (NSViewController *vc in self.childViewControllers) {
        if ([vc.title isEqualToString:itemIdentifier]) return vc;
    }
    return nil;
}

#pragma mark -
#pragma mark NSToolbarDelegate

- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    item.label = itemIdentifier;
    item.image = [NSImage imageNamed:NSStringFromClass([[self viewControllerForItemIdentifier:itemIdentifier] class])];
    item.target = self;
    item.action = @selector(toolbarItemClicked:);
    item.tag = [_toolbarIdentifiers indexOfObject:itemIdentifier];
    return item;
}

- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return _toolbarIdentifiers;
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return _toolbarIdentifiers;
}

- (NSArray<NSString *> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return _toolbarIdentifiers;
}

@end
