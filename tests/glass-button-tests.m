#import <AppKit/AppKit.h>
#import "GlassButtonGroup.h"
#import "ItsycalWindow.h"
#import "Themer.h"

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [Themer shared];
        NSButton *previous = [NSButton buttonWithTitle:@"Previous" target:nil action:nil];
        NSButton *next = [NSButton buttonWithTitle:@"Next" target:nil action:nil];
        GlassButtonGroup *group = [[GlassButtonGroup alloc] initWithButtons:@[previous, next]];
        group.frame = NSMakeRect(0, 0, 180, 26);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 220, 80) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        [window.contentView addSubview:group];
        group.usesGlass = YES;
        [group layoutSubtreeIfNeeded];
        NSGlassEffectView *glass = nil;
        for (NSView *view in group.subviews) if ([view isKindOfClass:NSGlassEffectView.class]) glass = (NSGlassEffectView *)view;
        if (!glass || ![glass.contentView isKindOfClass:NSStackView.class] || previous.superview != glass.contentView || next.superview != glass.contentView) return 1;
        if (NSWidth(glass.contentView.frame) != NSWidth(glass.bounds) || NSMaxX(next.frame) > NSWidth(glass.bounds) || NSMaxX(previous.frame) > NSMinX(next.frame)) return 4;
        group.usesGlass = NO;
        if (glass.contentView || previous.superview != group.subviews.lastObject || !glass.hidden) return 2;
        group.usesGlass = YES;
        if (!glass.contentView || glass.hidden) return 3;
        for (NSAppearanceName appearance in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
            NSApp.appearance = [NSAppearance appearanceNamed:appearance];
            [group layoutSubtreeIfNeeded];
            if (glass.contentView != previous.superview) return 5;
        }
        NSTextField *month = [NSTextField labelWithString:@"November 2026"];
        [month setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        NSButton *back = [NSButton buttonWithTitle:@"‹" target:nil action:nil];
        NSButton *forward = [NSButton buttonWithTitle:@"›" target:nil action:nil];
        GlassButtonGroup *header = [[GlassButtonGroup alloc] initWithViews:@[month, back, forward]];
        header.frame = NSMakeRect(0, 32, 300, 28);
        [window.contentView addSubview:header];
        header.usesGlass = YES;
        [header layoutSubtreeIfNeeded];
        NSGlassEffectView *headerGlass = (NSGlassEffectView *)header.subviews.firstObject;
        if (month.superview != headerGlass.contentView || back.superview != headerGlass.contentView || forward.superview != headerGlass.contentView) return 6;
        if (NSMinX(month.frame) < 0 || NSMaxX(forward.frame) > NSWidth(headerGlass.bounds) || NSMaxX(month.frame) > NSMinX(back.frame)) return 7;
        ItsycalWindow *popup = [ItsycalWindow new];
        NSView *frame = popup.contentView;
        NSVisualEffectView *material = nil;
        for (NSView *view in frame.subviews) if ([view isKindOfClass:NSVisualEffectView.class]) material = (NSVisualEffectView *)view;
        if (!material || material.material != NSVisualEffectMaterialPopover || material.blendingMode != NSVisualEffectBlendingModeBehindWindow) return 8;
        [frame setValue:@NO forKey:@"usesGlass"];
        if (!material.hidden) return 9;
        [frame setValue:@YES forKey:@"usesGlass"];
        BOOL accessibleFallback = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast;
        if (material.hidden != accessibleFallback) return 10;
        NSApp.appearance = nil;
        NSLog(@"PASS: glass controls, material popup, and live fallback");
    }
    return 0;
}
