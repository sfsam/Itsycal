#import "GlassButtonGroup.h"
#import "Itsycal.h"

@implementation GlassButtonGroup {
    NSGlassEffectView *_glass;
    NSStackView *_buttons;
}

- (instancetype)initWithButtons:(NSArray<NSButton *> *)buttons
{
    return [self initWithViews:buttons];
}

- (instancetype)initWithViews:(NSArray<NSView *> *)views
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _buttons = [NSStackView stackViewWithViews:views];
        _buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _buttons.alignment = NSLayoutAttributeCenterY;
        _buttons.spacing = 4;
        _buttons.edgeInsets = NSEdgeInsetsMake(0, 4, 0, 4);
        _glass = [NSGlassEffectView new];
        _glass.style = NSGlassEffectViewStyleRegular;
        _glass.cornerRadius = 10;
        _glass.effectIsInteractive = YES;
        _glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:_glass];
        [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(accessibilityOptionsChanged:) name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification object:nil];
        [self bind:@"usesGlass" toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[@"values." stringByAppendingString:kUseLiquidGlass] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    }
    return self;
}

- (void)dealloc
{
    [self unbind:@"usesGlass"];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (void)setUsesGlass:(BOOL)usesGlass
{
    _usesGlass = usesGlass;
    [self refreshPresentation];
}

- (void)accessibilityOptionsChanged:(NSNotification *)notification
{
    [self refreshPresentation];
}

- (void)refreshPresentation
{
    BOOL glassEnabled = _usesGlass && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast;
    if (glassEnabled) {
        if (_glass.contentView != _buttons) {
            [_buttons removeFromSuperview];
            _glass.contentView = _buttons;
        }
        _glass.hidden = NO;
    }
    else {
        if (_buttons.superview != self) {
            _glass.contentView = nil;
            [_buttons removeFromSuperview];
            [self addSubview:_buttons];
        }
        _glass.hidden = YES;
    }
    [self setNeedsLayout:YES];
}

- (NSSize)intrinsicContentSize
{
    CGFloat width = 8 + MAX(0, _buttons.arrangedSubviews.count - 1) * _buttons.spacing;
    CGFloat height = 26;
    for (NSView *view in _buttons.arrangedSubviews) width += view.intrinsicContentSize.width;
    return NSMakeSize(width, height);
}

- (void)layout
{
    [super layout];
    _glass.frame = self.bounds;
    if (_buttons.superview == self) _buttons.frame = NSInsetRect(self.bounds, 4, 2);
}

@end
