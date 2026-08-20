// Declarations for YouTube classes that Headers/YouTubeHeader does not cover,
// plus the extra members we need on the ones it does.

#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTCommonColorPalette.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <YouTubeHeader/YTRightNavigationButtons.h>
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTIPivotBarSupportedRenderers.h>
#import <YouTubeHeader/YTIPivotBarItemRenderer.h>
#import <YouTubeHeader/YTPivotBarItemView.h>
#import <YouTubeHeader/YTSettingsCell.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTCollectionViewController.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsSectionController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTUIUtils.h>
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIShelfSupportedRenderers.h>
#import <YouTubeHeader/YTIHorizontalListRenderer.h>
#import <YouTubeHeader/YTIHorizontalListSupportedRenderers.h>
#import <YouTubeHeader/YTIElementRenderer.h>

// YTColor.h in the submodule stops at black3.
@interface YTColor (YTMinimalUI)
+ (instancetype)black0;
+ (instancetype)black4;
@end

// The buttons on the right of the top bar. `connectionsInboxButton` is the
// Messages/DM button added in the 2025 releases (id.connections.inbox.button).
@interface YTRightNavigationButtons (YTMinimalUI)
@property (nonatomic, strong, readonly) UIView *notificationButton;
@property (nonatomic, strong, readonly) UIView *searchButton;
@property (nonatomic, strong, readonly) UIView *voiceSearchButton;
@property (nonatomic, strong, readonly) UIView *connectionsInboxButton;
@end

// The top bar's logo, and the container the doodle logo is drawn into.
@interface YTHeaderLogoController : NSObject
@end

@interface YTHeaderLogoControllerImpl : NSObject
@end

@interface YTNavigationBarTitleView : UIView
@end

@interface YTPivotBarView : UIView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer;
@end

@interface YTPivotBarViewController : UIViewController
- (void)selectItemWithPivotIdentifier:(NSString *)identifier;
@end

// A settings page keeps its rows in a collection view controller; reloading it
// is what re-runs every row's detailTextBlock.
@interface YTCollectionViewController (YTMinimalUI)
- (void)reloadData;
@end

// The picker's selectedItemIndex is handed straight to this.
@interface YTSettingsSectionController (YTMinimalUI)
- (void)setSelectedItem:(NSUInteger)selectedItem;
@end

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray <NSNumber *> *)settingsCategoryOrder;
@end

// Lists the setting groups, in order. Hooking it is how we get a group of our
// own above Account instead of a category inside it.
@interface YTAppSettingsGroupPresentationData : NSObject
+ (NSArray *)orderedGroups;
@end

// Where YouTube remembers whether you last had captions on. Backed by
// YTUserDefaults' "user.persistent_user_caption_visibility".
@interface MLCaptionConfigImpl : NSObject
@property (nonatomic) long long captionVisibility;
@end

@interface YTSettingsSectionItemManager (YTMinimalUI)
- (NSMutableArray <YTSettingsSectionItem *> *)ytMinimalUITweaksPageRows;
- (void)updateYTMinimalUISectionWithEntry:(id)entry;
@end
