#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>

// These glyphs are missed in Carbon.h
typedef NS_ENUM(unsigned short, kMASShortcutGlyph) {
    kMASShortcutGlyphEject = 0x23CF,
    kMASShortcutGlyphClear = 0x2715,
    kMASShortcutGlyphDeleteLeft = 0x232B,
    kMASShortcutGlyphDeleteRight = 0x2326,
    kMASShortcutGlyphLeftArrow = 0x2190,
    kMASShortcutGlyphRightArrow = 0x2192,
    kMASShortcutGlyphUpArrow = 0x2191,
    kMASShortcutGlyphDownArrow = 0x2193,
    kMASShortcutGlyphEscape = 0x238B,
    kMASShortcutGlyphHelp = 0x003F,
    kMASShortcutGlyphPageDown = 0x21DF,
    kMASShortcutGlyphPageUp = 0x21DE,
    kMASShortcutGlyphTabRight = 0x21E5,
    kMASShortcutGlyphReturn = 0x2305,
    kMASShortcutGlyphReturnR2L = 0x21A9,
    kMASShortcutGlyphPadClear = 0x2327,
    kMASShortcutGlyphNorthwestArrow = 0x2196,
    kMASShortcutGlyphSoutheastArrow = 0x2198,
};

// The missing function key definitions for `NS*FunctionKey`s
typedef NS_ENUM(unsigned short, kMASShortcutFuctionKey) {
    kMASShortcutEscapeFunctionKey = 0x001B,
    kMASShortcutDeleteFunctionKey = 0x0008,
    kMASShortcutSpaceFunctionKey = 0x0020,
    kMASShortcutReturnFunctionKey = 0x000D,
    kMASShortcutTabFunctionKey = 0x0009,
};

NS_INLINE NSString* NSStringFromMASKeyCode(unsigned short ch)
{
    return [NSString stringWithFormat:@"%C", ch];
}

NS_INLINE NSUInteger MASPickCocoaModifiers(NSUInteger flags)
{
    return (flags & (NSEventModifierFlagControl | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagCommand));
}

// Used in `-[MASShortcutValidator isShortcut:alreadyTakenInMenu:explanation:]`.
// This prevents incorrectly detecting an overlap with any shortcuts using the `fn` key.
NS_INLINE NSUInteger MASPickModifiersIncludingFn(NSUInteger flags)
{
    return (flags & (NSEventModifierFlagControl | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagCommand | NSEventModifierFlagFunction));
}

NS_INLINE UInt32 MASCarbonModifiersFromCocoaModifiers(NSUInteger cocoaFlags)
{
    return
          (cocoaFlags & NSEventModifierFlagCommand ? cmdKey : 0)
        | (cocoaFlags & NSEventModifierFlagOption ? optionKey : 0)
        | (cocoaFlags & NSEventModifierFlagControl ? controlKey : 0)
        | (cocoaFlags & NSEventModifierFlagShift ? shiftKey : 0);
}
