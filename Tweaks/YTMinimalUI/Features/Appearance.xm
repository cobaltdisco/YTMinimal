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
//
// The palette hooks only reach what YouTube colours through YTColor and
// YTCommonColorPalette. Sheets, the comment composer, the chip bars and live
// chat set a near-black background on the view itself, so each has to be
// painted by hand — see the second half of this file.

// Resolved per trait collection rather than read once, so the app's own
// light/dark switch is picked up without anything being re-applied. `light` is
// what the view gets outside dark mode: clear where something behind it
// already paints the background, white where nothing does.
static UIColor *YTMinimalUIBlackWhenDark(UIColor *light) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor blackColor] : light;
    }];
}

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

// Views that carry an accessibility identifier of their own. That identifier is
// the only stable handle on an ELM-rendered view: the class is always
// _ASDisplayView and the renderer behind it is an opaque blob.

%hook _ASDisplayView

- (void)didMoveToWindow {
    %orig;

    NSString *identifier = self.accessibilityIdentifier;

    // Each of these is a single grey block sitting on an otherwise black page.
    static NSSet <NSString *> *flatBackgrounds = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        flatBackgrounds = [NSSet setWithObjects:
            @"id.elements.components.comment_composer",
            @"id.subs.subscriptions_channel_bar",
            @"PAmedia_hub_device_picker.engagement_panel_header",
            nil];
    });
    if (identifier && [flatBackgrounds containsObject:identifier]) {
        self.backgroundColor = YTMinimalUIBlackWhenDark([UIColor clearColor]);
        return;
    }

    // The filter chips at the top of the feed are drawn on a container of their
    // own, so both levels have to be painted.
    if ([identifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
        UIColor *background = YTMinimalUIBlackWhenDark([UIColor clearColor]);
        self.backgroundColor = background;
        self.superview.backgroundColor = background;
        return;
    }

    UIViewController *controller = [self _viewControllerForAncestor];
    if (!controller) return;

    // Everything inside a sheet or a dialog: the "..." menu, the share sheet,
    // the quality picker.
    if ([controller isKindOfClass:%c(YTActionSheetDialogViewController)] || [controller isKindOfClass:%c(YTBottomSheetController)]) {
        // The subscribe button keeps its own colour.
        if ([self.superview.accessibilityIdentifier isEqualToString:@"eml.animated_subscribe_button"]) return;
        self.backgroundColor = YTMinimalUIBlackWhenDark([UIColor clearColor]);
        return;
    }

    // Live chat messages, except in the immersive layout drawn over the video,
    // where the transparent background is deliberate.
    if ([identifier isEqualToString:@"eml.live_chat_text_message"] && [controller isKindOfClass:%c(YCHAsyncLiveChatCollectionViewController)]) {
        if ([controller.view isKindOfClass:%c(YCHAsyncLiveChatImmersiveCollectionView)]) return;
        self.backgroundColor = YTMinimalUIBlackWhenDark([UIColor whiteColor]);
        return;
    }

    // A standalone ELM element names its template in the renderer description;
    // the transcript panel is the one worth catching.
    if ([controller isKindOfClass:%c(YTELMViewController)]) {
        id renderer = [controller valueForKey:@"_renderer"];
        if ([[renderer description] containsString:@"transcript_panel.eml"])
            self.backgroundColor = YTMinimalUIBlackWhenDark([UIColor clearColor]);
    }
}

%end

%hook ASCollectionView

- (void)didMoveToWindow {
    %orig;

    NSString *identifier = self.accessibilityIdentifier;
    if ([identifier isEqualToString:@"eml.chip_bar_collection"] || [identifier isEqualToString:@"subs_channel_bar.collection"]) {
        self.backgroundColor = YTMinimalUIBlackWhenDark([UIColor clearColor]);
    } else if ([identifier isEqualToString:@"id.elements.components.more_drawer_collection"]) {
        // The drawer's background belongs to the container above it.
        self.superview.backgroundColor = YTMinimalUIBlackWhenDark([UIColor whiteColor]);
    }
}

%end

// The half-height sheet YouTube uses for its newer menus.
%hook YTContextualWrapView

- (void)didMoveToWindow {
    %orig;
    if ([self.superview isKindOfClass:%c(YTContextualSheetView)])
        self.backgroundColor = YTMinimalUIBlackWhenDark([UIColor whiteColor]);
}

%end

// The ripple under a dialog's buttons, which otherwise stays grey against the
// black dialog. Sheets are left alone: they are already black from the pass
// above, and painting the ripple there squares off their rounded corners.
%hook MDCInkView

- (void)didMoveToWindow {
    %orig;
    if (![self.superview isKindOfClass:%c(GOODialogActionMDCButton)]) return;
    UIViewController *controller = [self _viewControllerForAncestor];
    if ([controller isKindOfClass:%c(YTBottomSheetController)] || [controller isKindOfClass:%c(GOOModalWindowViewController)]) return;
    self.backgroundColor = YTMinimalUIBlackWhenDark([UIColor clearColor]);
}

%end

// The bar pinned to the bottom of a panel (description, comments, transcript).
%hook YTEngagementPanelView

- (void)setFooterView:(UIView *)view {
    %orig;
    view.subviews.firstObject.backgroundColor = YTMinimalUIBlackWhenDark([UIColor clearColor]);
}

%end

// The launch splash, so the app does not flash grey before the feed appears.
%hook YTStartupAnimationViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.backgroundColor = YTMinimalUIBlackWhenDark([UIColor whiteColor]);
}

%end

%end

void YTMinimalUIInitAppearance(void) {
    // Colours are cached by the palette objects, so this can only be applied at
    // launch. The settings row says as much.
    if (YTMinimalUIBool(kOLEDDarkMode, NO)) %init(gOLEDDarkMode);
}
