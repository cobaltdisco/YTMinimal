#import "../YTMinimalUI.h"
#import "../Headers.h"
#import <dlfcn.h>

// YouTube's settings screen is two levels deep: `orderedGroups` lists group
// types, each group holds ordered categories, and a category is one titled
// section. Tweaks normally push their category into the Account group (type 1),
// which is why they all end up looking like part of Account.
//
// We register a group of our own instead, first in the list, so "YTMinimal"
// sits above Account and its categories get YouTube's native section headers.
//
// DontEatMyContent, YouChooseQuality and iSponsorBlock each register a section
// of their own. Rather than forking them we swallow those registrations and
// give each a row under "Video play" that opens its settings, wording and all,
// straight from its own bundle.

static const unsigned long long kYTMinimalUIGroup = 'ytmg';

// Everything lives behind one row, so one category is enough. The group title
// is the big native heading above Account; the category's own header is hidden
// so the row sits directly under it.
static const NSInteger kCategoryTweaks = 'ytmt';

// Sections we take over. Their ids come from the submodules' own sources:
// Tweaks/DontEatMyContent/Settings.x, Tweaks/YouChooseQuality/Settings.x and
// Tweaks/iSponsorBlock/iSponsorBlock.xm.
static const NSInteger kDontEatMyContentSection = 517;
static const NSInteger kYouChooseQualitySection = 'ycql';
static const NSInteger kSponsorBlockSection = 1081;

static NSArray <NSNumber *> *YTMinimalUICategories(void) {
    return @[@(kCategoryTweaks)];
}

static NSArray <NSNumber *> *YTMinimalUIWithoutTakenOverSections(NSArray <NSNumber *> *categories) {
    if (![categories isKindOfClass:[NSArray class]]) return categories;
    NSMutableArray <NSNumber *> *filtered = [categories mutableCopy];
    [filtered removeObject:@(kDontEatMyContentSection)];
    [filtered removeObject:@(kYouChooseQualitySection)];
    [filtered removeObject:@(kSponsorBlockSection)];
    [filtered removeObjectsInArray:YTMinimalUICategories()];
    return filtered;
}

#pragma mark - Bundles

static NSBundle *YTMinimalUINamedBundle(NSString *name) {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"bundle"];
    if (!path) path = [NSString stringWithFormat:@"/Library/Application Support/%@.bundle", name];
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    return [bundle load] || bundle.bundlePath ? bundle : nil;
}

NSBundle *YTMinimalUIBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ bundle = YTMinimalUINamedBundle(@"YTMinimalUI"); });
    return bundle;
}

// DontEatMyContent exports its own bundle lookup; using it keeps us on exactly
// the bundle it localises against.
static NSBundle *DontEatMyContentBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *(*getBundle)(void) = (NSBundle *(*)(void))dlsym(RTLD_DEFAULT, "DEMC_getTweakBundle");
        bundle = getBundle ? getBundle() : YTMinimalUINamedBundle(@"DontEatMyContent");
    });
    return bundle;
}

static NSBundle *YouChooseQualityBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ bundle = YTMinimalUINamedBundle(@"YouChooseQuality"); });
    return bundle;
}

#define DEMCLOC(key) [DontEatMyContentBundle() localizedStringForKey:key value:key table:nil]
#define YCQLOC(key) [YouChooseQualityBundle() localizedStringForKey:key value:key table:nil]

#pragma mark - Third-party preference keys
//
// Copied from the submodules. Re-check these when bumping them: a rename would
// leave a row that silently does nothing.

// Tweaks/DontEatMyContent/Tweak.h
#define kDEMCEnabled @"DEMC_enabled"
#define kDEMCSafeAreaConstant @"DEMC_safeAreaConstant"
#define kDEMCDisableAmbientMode @"DEMC_disableAmbientMode"
#define kDEMCColorViews @"DEMC_colorViewsEnabled"
#define kDEMCEnableForAllVideos @"DEMC_enableForAllVideos"
#define kDEMCDefaultConstant 21.5f

// Tweaks/YouChooseQuality/Settings.x and Scenario.h
#define kYCQEnabled @"YCQ-Enabled"
#define kYCQQualityPrefix @"YCQ-Quality"
#define kYCQDefaultQuality 108030
#define kYCQScenarioCount 5

static const int kYCQQualities[] = {
    216060, 216050, 216030,
    144060, 144050, 144030,
    108060, 108050, 108030,
     72060,  72050,  72030,
     48060,  48050,  48030,
     36060,  36050,  36030,
     24030,  14430,
};
static const NSUInteger kYCQQualityCount = sizeof(kYCQQualities) / sizeof(kYCQQualities[0]);

static NSString *YCQQualityKey(int scenario) {
    return [NSString stringWithFormat:@"%@-%d", kYCQQualityPrefix, scenario];
}

static NSString *YCQQualityLabel(int quality) {
    return [NSString stringWithFormat:@"%dp%d", quality / 100, quality % 100];
}

#pragma mark - Row builders

static YTSettingsSectionItem *YTMSwitchRow(NSString *title, NSString *description, NSString *key, BOOL fallback) {
    return [%c(YTSettingsSectionItem) switchItemWithTitle:title
        titleDescription:description
        accessibilityIdentifier:nil
        switchOn:YTMinimalUIBool(key, fallback)
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            YTMinimalUISetBool(key, enabled);
            return YES;
        }
        settingItemId:0];
}

// Small grey heading between blocks of rows. Sentence case, not upper case.
static YTSettingsSectionItem *YTMHeaderRow(NSString *title) {
    return [%c(YTSettingsSectionItem) itemWithTitle:@"\t"
        titleDescription:title
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) { return NO; }];
}

// Switch backed by another tweak's preference key, written verbatim.
static YTSettingsSectionItem *YTMForeignSwitchRow(NSString *title, NSString *description, NSString *key) {
    return [%c(YTSettingsSectionItem) switchItemWithTitle:title
        titleDescription:description
        accessibilityIdentifier:nil
        switchOn:[[NSUserDefaults standardUserDefaults] boolForKey:key]
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
            return YES;
        }
        settingItemId:0];
}

static void YTMPushPage(YTSettingsViewController *settings, id responder, NSString *title, NSArray <YTSettingsSectionItem *> *rows) {
    // YTSettingsPickerViewController doubles as a generic sub-page when it is
    // handed non-checkmark rows. It still forwards selectedItemIndex to the
    // section controller, which marks that row as chosen; the hook on
    // -[YTSettingsSectionController setSelectedItem:] below drops that when the
    // target is a switch, so 0 is harmless here.
    YTSettingsPickerViewController *page = [[%c(YTSettingsPickerViewController) alloc]
        initWithNavTitle:title
        pickerSectionTitle:nil
        rows:rows
        selectedItemIndex:0
        parentResponder:responder];
    [settings pushViewController:page];
}

#pragma mark - YouChooseQuality sub-page

static NSArray <YTSettingsSectionItem *> *YouChooseQualityRows(id responder, YTSettingsViewController *settings) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];

    [rows addObject:YTMForeignSwitchRow(YCQLOC(@"ENABLED"), YCQLOC(@"TWEAK_DESC"), kYCQEnabled)];

    for (int scenario = 0; scenario < kYCQScenarioCount; scenario++) {
        NSString *title = YCQLOC(([NSString stringWithFormat:@"QUALITY_FOR_SCENARIO_%d_SHORT", scenario]));
        NSString *description = YCQLOC(([NSString stringWithFormat:@"QUALITY_FOR_SCENARIO_%d", scenario]));
        [rows addObject:[%c(YTSettingsSectionItem) itemWithTitle:title
            titleDescription:description
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                NSInteger stored = [defaults integerForKey:YCQQualityKey(scenario)];
                return YCQQualityLabel((int)(stored ?: kYCQDefaultQuality));
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
                NSInteger stored = [defaults integerForKey:YCQQualityKey(scenario)] ?: kYCQDefaultQuality;
                NSMutableArray <YTSettingsSectionItem *> *choices = [NSMutableArray array];
                NSUInteger selectedIndex = 0;
                for (NSUInteger q = 0; q < kYCQQualityCount; q++) {
                    int quality = kYCQQualities[q];
                    if (quality == stored) selectedIndex = q;
                    [choices addObject:[%c(YTSettingsSectionItem) checkmarkItemWithTitle:YCQQualityLabel(quality)
                        selectBlock:^BOOL (YTSettingsCell *innerCell, NSUInteger innerIndex) {
                            [defaults setInteger:quality forKey:YCQQualityKey(scenario)];
                            [settings reloadData];
                            return YES;
                        }]];
                }
                YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                    initWithNavTitle:title
                    pickerSectionTitle:nil
                    rows:choices
                    selectedItemIndex:selectedIndex
                    parentResponder:responder];
                [settings pushViewController:picker];
                return YES;
            }]];
    }
    return rows;
}

#pragma mark - DontEatMyContent sub-page

// DontEatMyContent caches the safe area constant in an exported global that it
// reads once at launch. Writing the preference alone would not take effect
// until the next launch, so poke the global too, exactly as its own picker does.
static void DontEatMyContentSetConstant(float value) {
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:kDEMCSafeAreaConstant];
    CGFloat *constant = (CGFloat *)dlsym(RTLD_DEFAULT, "constant");
    if (constant) *constant = value;
}

static void DontEatMyContentShowSnackBar(NSString *text) {
    void (*showSnackBar)(NSString *) = (void (*)(NSString *))dlsym(RTLD_DEFAULT, "DEMC_showSnackBar");
    if (showSnackBar) showSnackBar(text);
}

static NSArray <YTSettingsSectionItem *> *DontEatMyContentRows(id responder, YTSettingsViewController *settings) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];

    // Upstream pops back to the settings list on this switch because its
    // advanced rows appear and disappear with it. We show those rows
    // unconditionally instead, so the page can stay put.
    [rows addObject:[%c(YTSettingsSectionItem) switchItemWithTitle:DEMCLOC(@"ENABLED")
        titleDescription:DEMCLOC(@"TWEAK_DESC")
        accessibilityIdentifier:nil
        switchOn:[defaults boolForKey:kDEMCEnabled]
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [defaults setBool:enabled forKey:kDEMCEnabled];
            DontEatMyContentShowSnackBar(DEMCLOC(@"CHANGES_SAVED"));
            return YES;
        }
        settingItemId:0]];
    [rows addObject:YTMForeignSwitchRow(DEMCLOC(@"DISABLE_AMBIENT_MODE"), nil, kDEMCDisableAmbientMode)];

    [rows addObject:YTMHeaderRow(DEMCLOC(@"ADVANCED"))];

    [rows addObject:[%c(YTSettingsSectionItem) itemWithTitle:DEMCLOC(@"SAFE_AREA_CONST")
        titleDescription:DEMCLOC(@"SAFE_AREA_CONST_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            float stored = [defaults floatForKey:kDEMCSafeAreaConstant];
            return [NSString stringWithFormat:@"%.1f", stored ?: kDEMCDefaultConstant];
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
            float stored = [defaults floatForKey:kDEMCSafeAreaConstant] ?: kDEMCDefaultConstant;
            NSMutableArray <YTSettingsSectionItem *> *choices = [NSMutableArray array];
            NSUInteger selectedIndex = 0, i = 0;
            for (float value = 20.0f; value <= 25.0f; value += 0.5f, i++) {
                float choice = value;
                if (fabsf(choice - stored) < 0.01f) selectedIndex = i;
                NSString *title = fabsf(choice - kDEMCDefaultConstant) < 0.01f
                    ? [NSString stringWithFormat:@"%.1f (%@)", choice, DEMCLOC(@"DEFAULT")]
                    : [NSString stringWithFormat:@"%.1f", choice];
                [choices addObject:[%c(YTSettingsSectionItem) checkmarkItemWithTitle:title
                    selectBlock:^BOOL (YTSettingsCell *innerCell, NSUInteger innerIndex) {
                        DontEatMyContentSetConstant(choice);
                        [settings reloadData];
                        DontEatMyContentShowSnackBar(DEMCLOC(@"CHANGES_SAVED_DISMISS_VIDEO"));
                        return YES;
                    }]];
            }
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                initWithNavTitle:DEMCLOC(@"SAFE_AREA_CONST")
                pickerSectionTitle:[DEMCLOC(@"SAFE_AREA_CONST") uppercaseString]
                rows:choices
                selectedItemIndex:selectedIndex
                parentResponder:responder];
            [settings pushViewController:picker];
            return YES;
        }]];

    [rows addObject:YTMForeignSwitchRow(DEMCLOC(@"COLOR_VIEWS"), DEMCLOC(@"COLOR_VIEWS_DESC"), kDEMCColorViews)];
    [rows addObject:YTMForeignSwitchRow(DEMCLOC(@"ENABLE_FOR_ALL_VIDEOS"), DEMCLOC(@"ENABLE_FOR_ALL_VIDEOS_DESC"), kDEMCEnableForAllVideos)];
    return rows;
}

#pragma mark - iSponsorBlock

// Mirrors presentSponsorBlockSettings() in Tweaks/iSponsorBlock/iSponsorBlock.xm,
// including its guard against presenting twice.
static void PresentSponsorBlockSettings(void) {
    Class controllerClass = NSClassFromString(@"SponsorBlockSettingsController");
    if (!controllerClass) return;

    id <UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
    if (![appDelegate respondsToSelector:@selector(window)]) return;
    UIViewController *presenter = [appDelegate window].rootViewController;

    while (presenter.presentedViewController) {
        UIViewController *presented = presenter.presentedViewController;
        if ([presented isKindOfClass:[UINavigationController class]] &&
            [((UINavigationController *)presented).viewControllers.firstObject isKindOfClass:controllerClass])
            return;
        presenter = presented;
    }

    UIViewController *settingsController = [[controllerClass alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settingsController];
    [presenter presentViewController:navigation animated:YES completion:nil];
}

#pragma mark - Sections

%group gSettingsItems

%hook YTSettingsSectionItemManager

%new(@@:)
- (NSMutableArray <YTSettingsSectionItem *> *)ytMinimalUITweaksPageRows {
    YTSettingsViewController *settings = [self valueForKey:@"_settingsViewControllerDelegate"];
    id responder = [self parentResponder];

    // Each of the six rows opens a page of its own, so the Tweaks page itself
    // stays a plain list — the same shape as YouTube's own settings.
    YTSettingsSectionItem *(^page)(NSString *, NSArray <YTSettingsSectionItem *> *(^)(void)) =
        ^YTSettingsSectionItem *(NSString *title, NSArray <YTSettingsSectionItem *> *(^build)(void)) {
            return [%c(YTSettingsSectionItem) itemWithTitle:title
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
                    YTMPushPage(settings, responder, title, build());
                    return YES;
                }];
        };

    NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];

    [rows addObject:page(YTMLOC(@"APPEARANCE"), ^NSArray <YTSettingsSectionItem *> *{
        return @[YTMSwitchRow(YTMLOC(@"OLED_DARK_MODE"), YTMLOC(@"OLED_DARK_MODE_DESC"), kOLEDDarkMode, NO)];
    })];

    [rows addObject:page(YTMLOC(@"NAVIGATION_BAR"), ^NSArray <YTSettingsSectionItem *> *{
        return @[
            YTMSwitchRow(YTMLOC(@"SHOW_MESSAGES"), nil, kShowMessagesButton, YES),
            YTMSwitchRow(YTMLOC(@"SHOW_NOTIFICATIONS"), nil, kShowNotificationsButton, YES),
            YTMSwitchRow(YTMLOC(@"SHOW_CAST"), nil, kShowCastButton, YES),
            YTMSwitchRow(YTMLOC(@"SHOW_VOICE_SEARCH"), nil, kShowVoiceSearchButton, YES),
        ];
    })];

    [rows addObject:page(YTMLOC(@"TAB_BAR"), ^NSArray <YTSettingsSectionItem *> *{
        NSArray <NSString *> *tabNames = @[YTMLOC(@"TAB_HOME"), YTMLOC(@"TAB_SHORTS"), YTMLOC(@"TAB_SUBSCRIPTIONS"), YTMLOC(@"TAB_YOU")];
        YTSettingsSectionItem *launchTab = [%c(YTSettingsSectionItem) itemWithTitle:YTMLOC(@"DEFAULT_TAB")
            titleDescription:YTMLOC(@"DEFAULT_TAB_DESC")
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                NSInteger index = YTMinimalUIInt(kDefaultTab, 0);
                return (index >= 0 && index < (NSInteger)tabNames.count) ? tabNames[index] : tabNames[0];
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
                NSMutableArray <YTSettingsSectionItem *> *choices = [NSMutableArray array];
                for (NSUInteger i = 0; i < tabNames.count; i++) {
                    NSUInteger choice = i;
                    [choices addObject:[%c(YTSettingsSectionItem) checkmarkItemWithTitle:tabNames[i]
                        selectBlock:^BOOL (YTSettingsCell *innerCell, NSUInteger innerIndex) {
                            YTMinimalUISetInt(kDefaultTab, choice);
                            return YES;
                        }]];
                }
                // A real checkmark list, so selectedItemIndex means what it says.
                YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                    initWithNavTitle:YTMLOC(@"DEFAULT_TAB")
                    pickerSectionTitle:nil
                    rows:choices
                    selectedItemIndex:YTMinimalUIInt(kDefaultTab, 0)
                    parentResponder:responder];
                [settings pushViewController:picker];
                return YES;
            }];
        return @[
            YTMSwitchRow(YTMLOC(@"SHOW_HOME_TAB"), nil, kShowHomeTab, YES),
            YTMSwitchRow(YTMLOC(@"SHOW_SHORTS_TAB"), nil, kShowShortsTab, YES),
            YTMSwitchRow(YTMLOC(@"SHOW_SUBSCRIPTIONS_TAB"), nil, kShowSubscriptionsTab, YES),
            YTMSwitchRow(YTMLOC(@"SHOW_CREATE_BUTTON"), nil, kShowCreateButton, YES),
            YTMSwitchRow(YTMLOC(@"SHOW_TAB_LABELS"), nil, kShowTabLabels, YES),
            launchTab,
        ];
    })];

    [rows addObject:page(YTMLOC(@"SHORTS"), ^NSArray <YTSettingsSectionItem *> *{
        return @[YTMSwitchRow(YTMLOC(@"SHOW_SHORTS_SHELF"), nil, kShowShortsShelf, YES)];
    })];

    [rows addObject:page(YTMLOC(@"VIDEO_PLAY"), ^NSArray <YTSettingsSectionItem *> *{
        // Each row is only offered when that tweak is actually in the build.
        NSMutableArray <YTSettingsSectionItem *> *videoRows = [NSMutableArray array];
        if (YouChooseQualityBundle()) {
            [videoRows addObject:[%c(YTSettingsSectionItem) itemWithTitle:@"YouChooseQuality"
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
                    YTMPushPage(settings, responder, @"YouChooseQuality", YouChooseQualityRows(responder, settings));
                    return YES;
                }]];
        }
        if (DontEatMyContentBundle()) {
            [videoRows addObject:[%c(YTSettingsSectionItem) itemWithTitle:@"DontEatMyContent"
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
                    YTMPushPage(settings, responder, @"DontEatMyContent", DontEatMyContentRows(responder, settings));
                    return YES;
                }]];
        }
        if (NSClassFromString(@"SponsorBlockSettingsController")) {
            [videoRows addObject:[%c(YTSettingsSectionItem) itemWithTitle:@"iSponsorBlock"
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
                    PresentSponsorBlockSettings();
                    return YES;
                }]];
        }
        return videoRows;
    })];

    [rows addObject:page(YTMLOC(@"ABOUT"), ^NSArray <YTSettingsSectionItem *> *{
        return @[[%c(YTSettingsSectionItem) itemWithTitle:@"YTMinimal"
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() { return @"v" TWEAK_VERSION; }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
                return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/cobaltdisco/YTMinimal"]];
            }]];
    })];

    return rows;
}

%new(v@:@)
- (void)updateYTMinimalUISectionWithEntry:(id)entry {
    YTSettingsViewController *settings = [self valueForKey:@"_settingsViewControllerDelegate"];

    YTSettingsSectionItem *entryRow = [%c(YTSettingsSectionItem) itemWithTitle:@"Tweaks"
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger index) {
            YTMPushPage(settings, [self parentResponder], @"Tweaks", [self ytMinimalUITweaksPageRows]);
            return YES;
        }];

    // The sliders icon, the same one YouMod puts on its settings entry.
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = YT_TUNE;
    entryRow.settingIcon = icon;

    // The icon goes on both the row and the section: YouMod's tune icon is
    // passed as a *section* icon, and it is not certain which of the two the
    // cell actually draws from.
    NSMutableArray <YTSettingsSectionItem *> *items = [NSMutableArray arrayWithObject:entryRow];
    if ([settings respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)])
        [settings setSectionItems:items forCategory:kCategoryTweaks title:nil icon:icon titleDescription:nil headerHidden:YES];
    else
        [settings setSectionItems:items forCategory:kCategoryTweaks title:nil titleDescription:nil headerHidden:YES];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if ((NSInteger)category == kCategoryTweaks) {
        [self updateYTMinimalUISectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

// A page built from switches has no "selected row", but the picker still hands
// its selectedItemIndex to the section controller, which marks that row as
// chosen — flipping the switch on regardless of the stored preference. Selection
// only ever means something on a checkmark list, so drop it when the target row
// carries a switch. (uYouEnhanced guards the same setter, for NSNotFound.)
%hook YTSettingsSectionController

- (void)setSelectedItem:(NSUInteger)selectedItem {
    if (selectedItem == NSNotFound) return;
    NSArray <YTSettingsSectionItem *> *items = self.items;
    if (selectedItem < items.count && items[selectedItem].hasSwitch) return;
    %orig;
}

%end

// Swallow the section registrations from the three tweaks we take over. This
// runs regardless of hook order, unlike filtering the category lists.
%hook YTSettingsViewController

- (void)setSectionItems:(NSMutableArray *)sectionItems forCategory:(NSInteger)category title:(NSString *)title titleDescription:(NSString *)titleDescription headerHidden:(BOOL)headerHidden {
    if (category == kDontEatMyContentSection || category == kYouChooseQualitySection || category == kSponsorBlockSection) return;
    %orig;
}

- (void)setSectionItems:(NSMutableArray *)sectionItems forCategory:(NSInteger)category title:(NSString *)title icon:(id)icon titleDescription:(NSString *)titleDescription headerHidden:(BOOL)headerHidden {
    if (category == kDontEatMyContentSection || category == kYouChooseQualitySection || category == kSponsorBlockSection) return;
    %orig;
}

%end

%end

#pragma mark - Group and category ordering

%group gSettingsOrder

%hook YTAppSettingsGroupPresentationData

+ (NSArray *)orderedGroups {
    NSArray *groups = %orig;
    if (![groups isKindOfClass:[NSArray class]]) return groups;
    NSMutableArray *ordered = [groups mutableCopy];

    // The list is group types on every build we have seen, but fall back to
    // building a group object if it ever turns out to hold those instead.
    if (groups.firstObject == nil || [groups.firstObject isKindOfClass:[NSNumber class]]) {
        [ordered removeObject:@(kYTMinimalUIGroup)];
        [ordered insertObject:@(kYTMinimalUIGroup) atIndex:0];
    } else {
        YTSettingsGroupData *group = [[%c(YTSettingsGroupData) alloc] initWithGroupType:kYTMinimalUIGroup];
        if (group) [ordered insertObject:group atIndex:0];
    }
    return ordered;
}

%end

%hook YTSettingsGroupData

- (NSString *)titleForSettingGroupType:(unsigned long long)type {
    if (type == kYTMinimalUIGroup) return @"YTMinimal";
    return %orig;
}

- (NSArray <NSNumber *> *)orderedCategoriesForGroupType:(unsigned long long)type {
    if (type == kYTMinimalUIGroup) return YTMinimalUICategories();
    NSArray <NSNumber *> *categories = %orig;
    return YTMinimalUIWithoutTakenOverSections(categories);
}

// Belt and braces: if -initWithGroupType: does not route through the two
// methods above, the cached values still come out right.
- (NSString *)title {
    if (self.type == kYTMinimalUIGroup) return @"YTMinimal";
    return %orig;
}

- (NSArray <NSNumber *> *)orderedCategories {
    if (self.type == kYTMinimalUIGroup) return YTMinimalUICategories();
    NSArray <NSNumber *> *categories = %orig;
    return YTMinimalUIWithoutTakenOverSections(categories);
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray <NSNumber *> *)settingsCategoryOrder {
    NSArray <NSNumber *> *order = %orig;
    NSMutableArray <NSNumber *> *reordered = [YTMinimalUIWithoutTakenOverSections(order) mutableCopy];
    NSIndexSet *head = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, YTMinimalUICategories().count)];
    [reordered insertObjects:YTMinimalUICategories() atIndexes:head];
    return reordered;
}

%end

%end

void YTMinimalUIInitSettings(void) {
    %init(gSettingsItems);

    // The ordering hooks have to be installed after every other tweak's, so
    // that %orig here returns lists that already contain their categories and
    // we get the last word. Every tweak's %ctor has run by the time the main
    // queue drains once.
    dispatch_async(dispatch_get_main_queue(), ^{
        %init(gSettingsOrder);
    });
}
