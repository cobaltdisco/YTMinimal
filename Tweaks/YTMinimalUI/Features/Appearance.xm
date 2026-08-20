#import "../YTMinimalUI.h"
#import "../Headers.h"

// OLED dark mode: replace YouTube's near-black greys with true black so the
// pixels are actually off on an OLED panel.
//
// Derived from YouMod (GPL-3.0) — https://github.com/Tonwalter888/YouMod
// Files/Apperence.x, which in turn credits uYouEnhanced.
//
// pageStyle == 1 is YouTube's dark theme; leaving light mode alone means the
// switch is safe to leave on.

%group gOLEDDarkMode

%hook YTColor
+ (UIColor *)black0 { return [UIColor blackColor]; }
+ (UIColor *)black1 { return [UIColor blackColor]; }
+ (UIColor *)black2 { return [UIColor blackColor]; }
+ (UIColor *)black3 { return [UIColor blackColor]; }
+ (UIColor *)black4 { return [UIColor blackColor]; }
%end

%hook YTCommonColorPalette
- (UIColor *)baseBackground {
    return self.pageStyle == 1 ? [UIColor blackColor] : %orig;
}
- (UIColor *)brandBackgroundSolid {
    return self.pageStyle == 1 ? [UIColor blackColor] : %orig;
}
- (UIColor *)brandBackgroundPrimary {
    return self.pageStyle == 1 ? [UIColor blackColor] : %orig;
}
- (UIColor *)brandBackgroundSecondary {
    return self.pageStyle == 1 ? [[UIColor blackColor] colorWithAlphaComponent:0.9] : %orig;
}
- (UIColor *)raisedBackground {
    return self.pageStyle == 1 ? [UIColor blackColor] : %orig;
}
- (UIColor *)staticBrandBlack {
    return self.pageStyle == 1 ? [UIColor blackColor] : %orig;
}
- (UIColor *)generalBackgroundA {
    return self.pageStyle == 1 ? [UIColor blackColor] : %orig;
}
%end

%hook YTInnerTubeCollectionViewController
- (UIColor *)backgroundColor:(NSInteger)pageStyle {
    return pageStyle == 1 ? [UIColor blackColor] : %orig;
}
%end

%end

void YTMinimalUIInitAppearance(void) {
    // Colours are cached by the palette objects, so this can only be applied at
    // launch. The settings row says as much.
    if (YTMinimalUIBool(kOLEDDarkMode, NO)) %init(gOLEDDarkMode);
}
