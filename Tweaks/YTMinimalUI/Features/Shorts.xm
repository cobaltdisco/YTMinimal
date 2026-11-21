#import "../YTMinimalUI.h"
#import "../Headers.h"
#import <objc/runtime.h>

// Dropping the Shorts shelf out of the feed.
//
// Derived from YTUnShorts by PoomSmart (MIT) via YouMod (GPL-3.0)
// https://github.com/PoomSmart/YTUnShorts
//
// Two shapes have to be caught, both still served in 21.46.3: the shelf
// renderer holding a horizontal list of shorts_video_cell elements (search
// results), and the single shorts_shelf.eml element section (Subscriptions).
//
// Each is also recognised by its Shorts header icon, youtube_shorts_24_cairo,
// the second signal YouMod checks — so renaming the cell template alone does
// not bring the shelf back. Only the header is looked at, never the whole
// section: Watch history marks each of its day sections
// history-shorts-shelf-item even when they hold no Shorts, and a match on the
// whole section would empty that page.

static const void *kYTMinimalUIIsShortsKey = &kYTMinimalUIIsShortsKey;

// -description serialises a renderer's whole protobuf tree to text, on the main
// thread. A feed section can hold a full page of videos, so describing whole
// sections on every "load more" — and every section already loaded, again, on
// each reload — is what made the feed stutter. Only the first element is looked
// at, which is all a Shorts shelf is, and the answer is kept on the section so
// a section is only ever described once.
static NSString *const kShortsHeaderIcon = @"youtube_shorts_24_cairo";

static BOOL YTMinimalUIDescriptionHasShorts(id renderer, NSString *marker) {
    return renderer && [[renderer description] containsString:marker];
}

// An ELM section's first element is either the shelf itself or a header
// above it. Either way it names the Shorts icon when it is a Shorts shelf;
// the date headers in Watch history do not.
static BOOL YTMinimalUIElementIsShortsShelf(id renderer) {
    if (!renderer) return NO;
    NSString *description = [renderer description];
    if ([description containsString:@"shorts_shelf.eml"]) return YES;
    return [description containsString:@"shelf_header.eml"] && [description containsString:kShortsHeaderIcon];
}

static BOOL YTMinimalUIIsShortsSection(YTIItemSectionRenderer *section) {
    NSNumber *cached = objc_getAssociatedObject(section, kYTMinimalUIIsShortsKey);
    if (cached) return cached.boolValue;

    BOOL isShorts = NO;
    if ([section isKindOfClass:%c(YTIShelfRenderer)]) {
        YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)section).content;
        YTIHorizontalListSupportedRenderers *first = content.horizontalListRenderer.itemsArray.firstObject;
        isShorts = YTMinimalUIDescriptionHasShorts(first.elementRenderer, @"shorts_video_cell");
        // The header is a field of its own, so this stays as cheap as the
        // check above. Missing on builds without it.
        if (!isShorts && [section respondsToSelector:@selector(headerRenderer)])
            isShorts = YTMinimalUIDescriptionHasShorts([(YTIShelfRenderer *)section headerRenderer], kShortsHeaderIcon);
    } else if ([section isKindOfClass:%c(YTIItemSectionRenderer)]) {
        YTIItemSectionSupportedRenderers *first = section.contentsArray.firstObject;
        isShorts = YTMinimalUIElementIsShortsShelf(first.elementRenderer);
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
