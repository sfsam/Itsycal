#import <AppKit/AppKit.h>

@interface GlassButtonGroup : NSView
- (instancetype)initWithButtons:(NSArray<NSButton *> *)buttons;
- (instancetype)initWithViews:(NSArray<NSView *> *)views;
@property (nonatomic) BOOL usesGlass;
@end
