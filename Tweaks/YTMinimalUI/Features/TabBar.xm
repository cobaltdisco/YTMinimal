#import "../YTMinimalUI.h"
#import "../Headers.h"

// Choosing which tabs the bottom bar shows, and which one the app opens on.
//
// Derived from YouMod (GPL-3.0) — https://github.com/Tonwalter888/YouMod
// Files/Tabbar.x.
//
// The items are dropped from the renderer before the bar is built rather than
// hidden afterwards, so the remaining tabs space themselves out properly.

// Pivot identifiers as used by the YouTube app. "FEuploads" sits on the
// icon-only renderer because the Create button has no label.
static NSString *const kHomePivot = @"FEwhat_to_watch";
static NSString *const kShortsPivot = @"FEshorts";
static NSString *const kCreatePivot = @"FEuploads";
static NSString *const kSubscriptionsPivot = @"FEsubscriptions";
static NSString *const kYouPivot = @"FElibrary";

// Drops the hidden tabs from the renderer in place. Running it twice on the
// same renderer is harmless.
static void YTMinimalUIFilterPivotBarRenderer(YTIPivotBarRenderer *renderer) {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    NSMutableIndexSet *indicesToRemove = [NSMutableIndexSet indexSet];

    for (NSUInteger i = 0; i < items.count; i++) {
        YTIPivotBarSupportedRenderers *item = items[i];
        NSString *identifier = [[item pivotBarItemRenderer] pivotIdentifier];
        NSString *iconOnlyIdentifier = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];

        if ([identifier isEqualToString:kHomePivot] && !YTMinimalUIBool(kShowHomeTab, YES))
            [indicesToRemove addIndex:i];
        else if ([identifier isEqualToString:kShortsPivot] && !YTMinimalUIBool(kShowShortsTab, YES))
            [indicesToRemove addIndex:i];
        else if ([identifier isEqualToString:kSubscriptionsPivot] && !YTMinimalUIBool(kShowSubscriptionsTab, YES))
            [indicesToRemove addIndex:i];
        else if ([iconOnlyIdentifier isEqualToString:kCreatePivot] && !YTMinimalUIBool(kShowCreateButton, YES))
            [indicesToRemove addIndex:i];
    }

    // Removed in one pass so the indices stay valid.
    [items removeObjectsAtIndexes:indicesToRemove];
}

%group gTabBar

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    YTMinimalUIFilterPivotBarRenderer(renderer);
    %orig;
}
%end

%end

// The floating bar (YouTube 21.4x, experiment-gated) replaces YTPivotBarView
// entirely, so it needs the same filter. Only initialised when the class exists.
%group gFloatingTabBar

// YouTube sizes the pill from its own intrinsicContentSize: YTAppView centres
// it, and the pill splits its width evenly between the tabs. +maxWidth is the
// width of the full five-tab pill, so a fifth of it is one tab's share.
//
// Left alone, hiding tabs barely shrinks the pill (360pt -> 315pt for three)
// and the leftover tabs just get wider. Instead each tab keeps its five-tab
// share, with a floor of two shares so a single tab is not a dot.
static const NSUInteger kFullTabCount = 5;
static const NSUInteger kMinTabShares = 2;

%hook YTFloatingPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    YTMinimalUIFilterPivotBarRenderer(renderer);
    %orig;
}

- (CGSize)intrinsicContentSize {
    CGSize size = %orig;
    NSUInteger count = [[self.renderer itemsArray] count];
    CGFloat share = [[self class] maxWidth] / kFullTabCount;
    if (count == 0 || share <= 0) return size;
    CGFloat width = MAX(count, kMinTabShares) * share;
    // Only ever narrower than YouTube's own choice.
    if (width < size.width) size.width = width;
    return size;
}
%end

%end

// Pins the bar to the style picked in settings. Both values otherwise come
// from server config, which flips between launches. Floating style 1 is the
// frosted one; 0 and 2-5 are all solid black. Read once at launch, because
// YouTube only makes this choice at launch.
static BOOL gUseFloatingBar = YES;
static long long gFloatingBarStyle = 1;

%group gForceFloatingBar

%hook YTFloatingBarExperiment
+ (BOOL)enableFloatingBottomBar {
    return gUseFloatingBar;
}
+ (long long)floatingBarStyle {
    return gFloatingBarStyle;
}
%end

%end

%group gForceFloatingBarConfig

%hook YTColdConfig
- (long long)mainAppCoreClientIosFloatingBarStyle {
    return gFloatingBarStyle;
}
%end

%end

%group gHideTabLabels

%hook YTPivotBarItemView
- (void)setRenderer:(YTIPivotBarItemRenderer *)renderer {
    %orig;
    [self.navigationButton setTitle:@"" forState:UIControlStateNormal];
    self.navigationButton.sizeWithPaddingAndInsets = NO;
}
%end

%end

%group gDefaultTab

static BOOL YTMinimalUIDidSelectStartupTab = NO;

%hook YTPivotBarViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (YTMinimalUIDidSelectStartupTab) return;
    YTMinimalUIDidSelectStartupTab = YES;

    NSArray <NSString *> *pivots = @[kHomePivot, kShortsPivot, kSubscriptionsPivot, kYouPivot];
    NSInteger index = YTMinimalUIInt(kDefaultTab, 0);
    if (index < 0 || index >= (NSInteger)pivots.count) return;
    [self selectItemWithPivotIdentifier:pivots[index]];
}
%end

%end

void YTMinimalUIInitTabBar(void) {
    %init(gTabBar);
    // The floating bar only exists in newer YouTube builds; on older ones
    // every hook below is skipped and the classic bar is left alone.
    Class floatingBar = objc_getClass("YTFloatingPivotBarView");
    if (floatingBar && [floatingBar respondsToSelector:@selector(maxWidth)]) {
        %init(gFloatingTabBar);
        NSInteger style = YTMinimalUIInt(kTabBarStyle, YTMinimalUITabBarStyleFloatingFrosted);
        gUseFloatingBar = style != YTMinimalUITabBarStyleClassic;
        gFloatingBarStyle = style == YTMinimalUITabBarStyleFloatingSolid ? 0 : 1;
        Class experiment = objc_getClass("YTFloatingBarExperiment");
        if ([experiment respondsToSelector:@selector(enableFloatingBottomBar)]
            && [experiment respondsToSelector:@selector(floatingBarStyle)])
            %init(gForceFloatingBar);
        if ([objc_getClass("YTColdConfig") instancesRespondToSelector:@selector(mainAppCoreClientIosFloatingBarStyle)])
            %init(gForceFloatingBarConfig);
    }
    if (!YTMinimalUIBool(kShowTabLabels, YES)) %init(gHideTabLabels);
    if (YTMinimalUIInt(kDefaultTab, 0) != 0) %init(gDefaultTab);
}
