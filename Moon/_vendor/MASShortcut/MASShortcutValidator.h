#import "MASShortcut.h"

@interface MASShortcutValidator : NSObject

// The following API enable hotkeys with the Option key as the only modifier
// For example, Option-G will not generate © and Option-R will not paste ®
@property(assign) BOOL allowAnyShortcutWithOptionModifier;

+ (instancetype) sharedValidator;

- (BOOL) isShortcutValid: (MASShortcut*) shortcut;
- (BOOL) isShortcut: (MASShortcut*) shortcut alreadyTakenInMenu: (NSMenu*) menu explanation: (NSString**) explanation;
- (BOOL) isShortcutAlreadyTakenBySystem: (MASShortcut*) shortcut explanation: (NSString**) explanation;

@end
