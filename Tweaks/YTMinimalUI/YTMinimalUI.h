#import <UIKit/UIKit.h>

// Preferences are plain NSUserDefaults keys under the YouTube app's own domain,
// namespaced with "YTMinimalUI" so they never collide with YouTube's or another
// tweak's keys. No PreferenceLoader bundle: the settings UI is injected into
// YouTube's own settings screen (see Features/Settings.xm).
#define kYTMinimalUIPrefix @"YTMinimalUI"

// Appearance
#define kOLEDDarkMode @"OLEDDarkMode"

// Navigation bar. Stored as "show", default on, so every switch reads the same
// way round: off means the button is gone.
#define kShowMessagesButton @"ShowMessagesButton"
#define kShowNotificationsButton @"ShowNotificationsButton"
#define kShowCastButton @"ShowCastButton"
#define kShowVoiceSearchButton @"ShowVoiceSearchButton"

// Tab bar. The "You" tab deliberately has no switch — hiding every tab would
// leave no way back into the settings screen.
#define kShowHomeTab @"ShowHomeTab"
#define kShowShortsTab @"ShowShortsTab"
#define kShowSubscriptionsTab @"ShowSubscriptionsTab"
#define kShowCreateButton @"ShowCreateButton"
#define kShowTabLabels @"ShowTabLabels"
#define kDefaultTab @"DefaultTab"

// Shorts
#define kShowShortsShelf @"ShowShortsShelf"

static inline NSString *YTMinimalUIKey(NSString *name) {
    return [kYTMinimalUIPrefix stringByAppendingString:name];
}

// Reads a boolean preference. `fallback` is returned when the key was never set,
// so each feature decides whether it is opt-in or opt-out.
static inline BOOL YTMinimalUIBool(NSString *name, BOOL fallback) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:YTMinimalUIKey(name)];
    return value == nil ? fallback : [value boolValue];
}

static inline void YTMinimalUISetBool(NSString *name, BOOL value) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:YTMinimalUIKey(name)];
}

static inline NSInteger YTMinimalUIInt(NSString *name, NSInteger fallback) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:YTMinimalUIKey(name)];
    return value == nil ? fallback : [value integerValue];
}

static inline void YTMinimalUISetInt(NSString *name, NSInteger value) {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:YTMinimalUIKey(name)];
}

// Localized strings live in YTMinimalUI.bundle (en + zh-Hans) and follow the
// YouTube app's language, not the system one.
NSBundle *YTMinimalUIBundle(void);
#define YTMLOC(key) [YTMinimalUIBundle() localizedStringForKey:key value:key table:nil]

// Every Features/<Name>.xm defines one of these and gets called from %ctor.
void YTMinimalUIInitAppearance(void);
void YTMinimalUIInitNavigationBar(void);
void YTMinimalUIInitTabBar(void);
void YTMinimalUIInitShorts(void);
void YTMinimalUIInitSettings(void);
