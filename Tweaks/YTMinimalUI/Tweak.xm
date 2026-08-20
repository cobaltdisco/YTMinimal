#import "YTMinimalUI.h"

// YTMinimalUI — the interface tweaks written for this fork.
//
// Each feature lives in its own Features/<Name>.xm, declares a %group, and
// exposes a `void YTMinimalUIInit<Name>(void)` that decides whether to
// %init that group. This file only wires them together, so features stay
// independent and can be dropped or disabled one at a time.

%ctor {
    @autoreleasepool {
        YTMinimalUIInitAppearance();
        YTMinimalUIInitNavigationBar();
        YTMinimalUIInitTabBar();
        YTMinimalUIInitShorts();
        YTMinimalUIInitSubtitles();
        YTMinimalUIInitSettings();
    }
}
