#import "../YTMinimalUI.h"
#import "../Headers.h"

// Keeping YouTube's theme in step with the system one across a trip to the
// background.
//
// YouTube does not theme through UIKit traits. YTPageStyleControllerImpl holds
// a "page style" (0 light, 1 dark) and broadcasts changes, and that broadcast
// is what swaps the ELM theme behind every feed cell, the header logo and the
// feed's cached background. It is sent from -[YTMainWindow
// traitCollectionDidChange:] — except in the background, where the window only
// flips a `_systemThemeChangedWhileInBackground` bit and replays the change on
// the way back in. The bit is toggled, not set, so that the light/dark pair
// iOS renders for the app switcher cancels out; one trait change that goes
// uncounted and the replay never happens.
//
// Meanwhile -pageStyle is not stored when the app follows the device theme: it
// is read from the current trait collection on every call. So whatever asks
// after the missed broadcast gets the new style, and whatever was waiting to be
// told keeps the old one — white titles on a white feed, a dark tab bar under a
// light page.
//
// Rather than trust the bit, this compares the two ends once the app is active
// again: the style the observers were last told, against the one the window
// actually has. If they differ, the broadcast is sent again.

// YTPageStyleControllerImpl.appThemeSetting when following the device.
static const NSInteger kAppThemeSettingDevice = 1;

static __weak YTPageStyleControllerImpl *pageStyleController = nil;
// What the observers were last told. Main thread only.
static NSInteger notifiedPageStyle = NSNotFound;

static void YTMinimalUIResyncPageStyle(void) {
    YTPageStyleControllerImpl *controller = pageStyleController;
    if (!controller || controller.appThemeSetting != kAppThemeSettingDevice) return;
    if (![controller respondsToSelector:@selector(systemThemeDidChange)]) return;

    Class windowUtils = %c(YTMainWindowUtils);
    if (![windowUtils respondsToSelector:@selector(mainWindow)]) return;
    UITraitCollection *traits = [windowUtils mainWindow].traitCollection;
    if (!traits) return;

    NSInteger pageStyle = traits.userInterfaceStyle == UIUserInterfaceStyleDark ? 1 : 0;
    // Nothing has been broadcast since launch, and the app starts out in step.
    if (notifiedPageStyle == NSNotFound) {
        notifiedPageStyle = pageStyle;
        return;
    }
    if (notifiedPageStyle == pageStyle) return;

    // The observers read -pageStyle back while they are being told, and that
    // reads the *current* trait collection, which outside a layout pass is
    // whatever UIKit last left there. Pin it to the window's for the duration.
    [traits performAsCurrentTraitCollection:^{
        [controller systemThemeDidChange];
    }];
}

%group gPageStyleSync

%hook YTPageStyleControllerImpl

- (id)initWithSystemNotifications:(id)systemNotifications {
    id controller = %orig;
    pageStyleController = controller;
    return controller;
}

- (void)notifyObservers {
    pageStyleController = self;
    notifiedPageStyle = self.pageStyle;
    %orig;
}

%end

%end

// Always installed: it only acts when the two ends disagree, which is the state
// this exists to get out of.
void YTMinimalUIInitPageStyle(void) {
    %init(gPageStyleSync);
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        YTMinimalUIResyncPageStyle();
    }];
}
