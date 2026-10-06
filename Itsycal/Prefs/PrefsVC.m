//
//  Created by Sanjay Madan on 1/29/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsVC.h"
#import "PrefsAboutVC.h"

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
    [self selectTabAtIndex:[self aboutTabIndex]];
}

- (void)showPrefs
{
    if (_selectedItemTag == [self aboutTabIndex]) {
        [self selectTabAtIndex:0]; // General is the first tab.
    }
}

- (NSInteger)aboutTabIndex
{
    return [self.childViewControllers indexOfObjectPassingTest:^BOOL(NSViewController *vc, NSUInteger idx, BOOL *stop) {
        return [vc isKindOfClass:[PrefsAboutVC class]];
    }];
}

- (void)selectTabAtIndex:(NSInteger)index
{
    NSString *identifier = _toolbarIdentifiers[index];
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    item.tag = index;
    _toolbar.selectedItemIdentifier = identifier;
    [self switchToTabForToolbarItem:item animated:NO];
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

    NSViewController *toVC = [self viewControllerForItemIdentifier:item.itemIdentifier];
    if (toVC == nil) return;

    _selectedItemTag = item.tag;

    NSWindow *window = self.view.window;
    NSRect contentRect = NSMakeRect(0, 0, _contentWidth, toVC.view.fittingSize.height);
    NSRect contentFrame = [window frameRectForContentRect:contentRect];
    CGFloat windowHeightDelta = window.frame.size.height - contentFrame.size.height;
    NSPoint newOrigin = NSMakePoint(window.frame.origin.x, window.frame.origin.y + windowHeightDelta);
    NSRect newFrame = (NSRect){newOrigin, contentFrame.size};

    // Only the selected tab's view is ever in self.view. The old tab's
    // view disappears at once (only the new one fades in), so remove it
    // now instead of when the animation ends. That way switching again
    // before the animation ends needs no special handling.
    for (NSView *view in [self.view.subviews copy]) {
        if (view != toVC.view) [view removeFromSuperview];
    }

    [toVC.view setAlphaValue:0];
    [toVC.view setFrame:contentRect];
    [self.view addSubview:toVC.view];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        [context setDuration:animated ? 0.2 : 0];
        [window.animator setFrame:newFrame display:NO];
        [toVC.view.animator setAlphaValue:1];
    }];
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
