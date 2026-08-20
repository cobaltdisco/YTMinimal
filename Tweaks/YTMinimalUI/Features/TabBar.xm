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

%group gTabBar

%hook YTPivotBarView

- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
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
    %orig(renderer);
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
    if (!YTMinimalUIBool(kShowTabLabels, YES)) %init(gHideTabLabels);
    if (YTMinimalUIInt(kDefaultTab, 0) != 0) %init(gDefaultTab);
}
