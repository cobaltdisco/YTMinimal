#import "../YTMinimalUI.h"
#import "../Headers.h"

// YouTube remembers the last caption toggle you made while watching and carries
// it into the next video. MLCaptionConfigImpl holds that memory — it persists
// it as "user.persistent_user_caption_visibility" — and the per-video caption
// loader reads it back through -[MLCaptionConfigImpl captionVisibility], in
// -[MLInnerTubeCaptionController loadUserCaptionsWithSelectionReason:] and
// -loadUserCaptionsBasedOnPastUserSelectionWithSelectionReason:.
//
// Forcing that one getter is enough to pin the state, and it is the least
// invasive place to do it: -setSelectedCaptionTrack:selectionReason:, which is
// what the CC button in the player calls, loads the track directly and never
// reads the visibility back, so toggling captions for the video you are
// watching keeps working exactly as before. The choice simply stops being
// remembered — the next video, and a cold start, read our setting instead.
//
// The values are YouTube's own, from -[MLCaptionConfigImpl init]:
// 0 unset (fall back to the iOS "Closed Captions + SDH" setting), 1 shown,
// 2 hidden.
static const long long kCaptionVisibilityShown = 1;
static const long long kCaptionVisibilityHidden = 2;

%group gForceSubtitles
%hook MLCaptionConfigImpl

- (long long)captionVisibility {
    if (!YTMinimalUIBool(kForceSubtitles, NO)) {
        long long visibility = %orig;
        return visibility;
    }
    return YTMinimalUIBool(kSubtitlesOn, NO) ? kCaptionVisibilityShown : kCaptionVisibilityHidden;
}

%end
%end

// Always installed: the hook reads the preference on every call, so the setting
// takes effect on the next video rather than on the next launch.
void YTMinimalUIInitSubtitles(void) {
    %init(gForceSubtitles);
}
