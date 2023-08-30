#import "MASShortcut.h"

/**
 This class is used by the recording control to tell which shortcuts are acceptable.

 There are two kinds of shortcuts that are not considered acceptable: shortcuts that
 are too simple (like single letter keys) and shortcuts that are already used by the
 operating system.
*/
@interface MASShortcutValidator : NSObject

/**
 Set to `YES` if you want to accept Option-something shortcuts.

 `NO` by default, since Option-something shortcuts are often used by system,
 for example Option-G will type the © sign. This also applies to Option-Shift
 shortcuts – in other words, shortcut recorder will not accept shortcuts like
 Option-Shift-K by default. (Again, since Option-Shift-K inserts the Apple
 logo sign by default.)
*/
@property(assign) BOOL allowAnyShortcutWithOptionModifier;

/**
 Set to `YES` if you want to accept shortcuts that override the Services menu
 item.

 `NO` by default. Set to `YES` to allow shortcuts to override key equivalents of
 Services menu items. This can prevent users from being confused when they can't
 find the conflicting menu item since menu items in the Services menu are not
 always visible.
*/
@property(assign) BOOL allowOverridingServicesShortcut;

+ (instancetype) sharedValidator;

- (BOOL) isShortcutValid: (MASShortcut*) shortcut;
- (BOOL) isShortcut: (MASShortcut*) shortcut alreadyTakenInMenu: (NSMenu*) menu explanation: (NSString**) explanation;
- (BOOL) isShortcutAlreadyTakenBySystem: (MASShortcut*) shortcut explanation: (NSString**) explanation;

@end
