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
    CGFloat _contentWidth; // Same for every tab; only the height changes.
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
        self.view.window.toolbarStyle = NSWindowToolbarStylePreference;
        [self widenWindowToFitToolbar];
    }
}

- (void)widenWindowToFitToolbar
{
    // If the window is too narrow for the tab labels (which happens
    // in some languages), the toolbar moves tabs into its overflow
    // menu. AppKit has no option to prevent that, but it does report
    // which items are visible, and updates that synchronously on
    // layout. So widen the window until every item is visible. All
    // tabs then use the new width.
    NSWindow *window = self.view.window;
    CGFloat maxWidth = NSWidth(window.screen.visibleFrame);
    [window layoutIfNeeded];
    if (_toolbar.visibleItems == nil) return; // Toolbar not laid out yet.
    while (_toolbar.visibleItems.count < _toolbar.items.count
           && NSWidth(window.frame) + 10 <= maxWidth) {
        CGFloat oldWidth = NSWidth(window.frame);
        NSRect frame = NSInsetRect(window.frame, -5, 0);
        [window setFrame:frame display:NO];
        [window layoutIfNeeded];
        if (NSWidth(window.frame) <= oldWidth) break; // Couldn't widen.
        _contentWidth = NSWidth([window contentRectForFrameRect:window.frame]);
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
    // Every tab uses the width of the widest tab, so the window
    // only changes height when switching tabs.
    for (NSViewController *childViewController in childViewControllers) {
        [_toolbarIdentifiers addObject:childViewController.title];
        _contentWidth = MAX(_contentWidth, childViewController.view.fittingSize.width);
        childViewController.view.autoresizingMask = NSViewWidthSizable;
    }
    [self.view setFrame:NSMakeRect(0, 0, _contentWidth, childViewControllers[0].view.fittingSize.height)];
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
        NSRect contentRect = NSMakeRect(0, 0, _contentWidth, toVC.view.fittingSize.height);
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
