#import <AppKit/AppKit.h>

@class MASShortcut, MASShortcutValidator;

extern NSString * _Nonnull const MASShortcutBinding;

typedef NS_ENUM(NSInteger, MASShortcutViewStyle) {
    MASShortcutViewStyleDefault = 0,  // Height = 19 px
    MASShortcutViewStyleTexturedRect, // Height = 25 px
    MASShortcutViewStyleRounded,      // Height = 43 px
    MASShortcutViewStyleFlat,
    MASShortcutViewStyleRegularSquare
};

@interface MASShortcutView : NSView

@property (nonatomic, strong, nullable) MASShortcut *shortcutValue;
@property (nonatomic, strong, nullable) MASShortcutValidator *shortcutValidator;
@property (nonatomic, getter = isRecording) BOOL recording;
@property (nonatomic, getter = isEnabled) BOOL enabled;
@property (nonatomic, copy, nullable) void (^shortcutValueChange)(MASShortcutView * _Nonnull sender);
@property (nonatomic, assign) MASShortcutViewStyle style;

/// Returns custom class for drawing control.
+ (nonnull Class)shortcutCellClass;

- (void)setAcceptsFirstResponder:(BOOL)value;

@end
