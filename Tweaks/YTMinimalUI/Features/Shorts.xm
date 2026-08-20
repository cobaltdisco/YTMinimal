#import "../YTMinimalUI.h"
#import "../Headers.h"

// Dropping the Shorts shelf out of the feed.
//
// Derived from YTUnShorts by PoomSmart (MIT) via YouMod (GPL-3.0)
// https://github.com/PoomSmart/YTUnShorts
//
// Two shapes have to be caught: the older shelf renderer holding a horizontal
// list of shorts_video_cell elements, and the newer single shorts_shelf.eml
// element section.

static NSMutableArray <YTIItemSectionRenderer *> *YTMinimalUIFeedWithoutShorts(NSArray <YTIItemSectionRenderer *> *sections) {
    NSMutableArray <YTIItemSectionRenderer *> *filtered = [sections mutableCopy];
    NSIndexSet *shortsSections = [filtered indexesOfObjectsPassingTest:^BOOL (YTIItemSectionRenderer *section, NSUInteger idx, BOOL *stop) {
        if ([section isKindOfClass:%c(YTIShelfRenderer)]) {
            YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)section).content;
            NSMutableArray <YTIHorizontalListSupportedRenderers *> *items = content.horizontalListRenderer.itemsArray;
            NSIndexSet *shortsItems = [items indexesOfObjectsPassingTest:^BOOL (YTIHorizontalListSupportedRenderers *item, NSUInteger idx2, BOOL *stop2) {
                BOOL isShorts = [[item.elementRenderer description] containsString:@"shorts_video_cell"];
                if (isShorts) *stop2 = YES;
                return isShorts;
            }];
            return shortsItems.count > 0;
        }
        if ([section isKindOfClass:%c(YTIItemSectionRenderer)])
            return [[section description] containsString:@"shorts_shelf.eml"];
        return NO;
    }];
    [filtered removeObjectsAtIndexes:shortsSections];
    return filtered;
}

%group gHideShortsShelf

%hook YTInnerTubeCollectionViewController

- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sections = [self valueForKey:@"_sectionRenderers"];
    if (sections) [self setValue:YTMinimalUIFeedWithoutShorts(sections) forKey:@"_sectionRenderers"];
    %orig;
}

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    %orig(YTMinimalUIFeedWithoutShorts(array));
}

%end

%end

void YTMinimalUIInitShorts(void) {
    if (!YTMinimalUIBool(kShowShortsShelf, YES)) %init(gHideShortsShelf);
}
