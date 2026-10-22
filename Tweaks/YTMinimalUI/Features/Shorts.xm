#import "../YTMinimalUI.h"
#import "../Headers.h"
#import <objc/runtime.h>

// Dropping the Shorts shelf out of the feed.
//
// Derived from YTUnShorts by PoomSmart (MIT) via YouMod (GPL-3.0)
// https://github.com/PoomSmart/YTUnShorts
//
// Two shapes have to be caught: the older shelf renderer holding a horizontal
// list of shorts_video_cell elements, and the newer single shorts_shelf.eml
// element section.

static const void *kYTMinimalUIIsShortsKey = &kYTMinimalUIIsShortsKey;

// -description serialises a renderer's whole protobuf tree to text, on the main
// thread. A feed section can hold a full page of videos, so describing whole
// sections on every "load more" — and every section already loaded, again, on
// each reload — is what made the feed stutter. Only the first element is looked
// at, which is all a Shorts shelf is, and the answer is kept on the section so
// a section is only ever described once.
static BOOL YTMinimalUIDescriptionHasShorts(id renderer, NSString *marker) {
    return renderer && [[renderer description] containsString:marker];
}

static BOOL YTMinimalUIIsShortsSection(YTIItemSectionRenderer *section) {
    NSNumber *cached = objc_getAssociatedObject(section, kYTMinimalUIIsShortsKey);
    if (cached) return cached.boolValue;

    BOOL isShorts = NO;
    if ([section isKindOfClass:%c(YTIShelfRenderer)]) {
        YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)section).content;
        YTIHorizontalListSupportedRenderers *first = content.horizontalListRenderer.itemsArray.firstObject;
        isShorts = YTMinimalUIDescriptionHasShorts(first.elementRenderer, @"shorts_video_cell");
    } else if ([section isKindOfClass:%c(YTIItemSectionRenderer)]) {
        YTIItemSectionSupportedRenderers *first = section.contentsArray.firstObject;
        isShorts = YTMinimalUIDescriptionHasShorts(first.elementRenderer, @"shorts_shelf.eml");
    }
    objc_setAssociatedObject(section, kYTMinimalUIIsShortsKey, @(isShorts), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return isShorts;
}

// nil when nothing had to be dropped, so the caller can leave the array alone.
static NSMutableArray <YTIItemSectionRenderer *> *YTMinimalUIFeedWithoutShorts(NSArray <YTIItemSectionRenderer *> *sections) {
    NSIndexSet *shortsSections = [sections indexesOfObjectsPassingTest:^BOOL (YTIItemSectionRenderer *section, NSUInteger idx, BOOL *stop) {
        return YTMinimalUIIsShortsSection(section);
    }];
    if (shortsSections.count == 0) return nil;
    NSMutableArray <YTIItemSectionRenderer *> *filtered = [sections mutableCopy];
    [filtered removeObjectsAtIndexes:shortsSections];
    return filtered;
}

%group gHideShortsShelf

%hook YTInnerTubeCollectionViewController

- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *filtered = YTMinimalUIFeedWithoutShorts([self valueForKey:@"_sectionRenderers"]);
    if (filtered) [self setValue:filtered forKey:@"_sectionRenderers"];
    %orig;
}

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    NSArray *filtered = YTMinimalUIFeedWithoutShorts(array) ?: array;
    %orig(filtered);
}

%end

%end

void YTMinimalUIInitShorts(void) {
    if (!YTMinimalUIBool(kShowShortsShelf, YES)) %init(gHideShortsShelf);
}
