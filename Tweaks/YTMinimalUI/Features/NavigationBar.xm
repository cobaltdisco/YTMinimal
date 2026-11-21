#import "../YTMinimalUI.h"
#import "../Headers.h"
#import <objc/runtime.h>

// Hiding buttons in the top bar.
//
// The button-hiding pass is derived from YouMod (GPL-3.0)
// https://github.com/Tonwalter888/YouMod Files/Navbar.x. The Messages button
// (`connectionsInboxButton` / id.connections.inbox.button) is new in the 2025
// YouTube releases and is not covered there.
//
// Hiding happens in -layoutSubviews rather than by removing the views, because
// YouTube re-lays out the bar whenever the top bar is rebuilt and would
// otherwise put the buttons back.

static void YTMinimalUIHideSubviewWithIdentifier(UIView *container, NSString *identifier) {
    for (UIView *subview in container.subviews) {
        if ([subview.accessibilityIdentifier isEqualToString:identifier]) subview.hidden = YES;
    }
}

%group gNavigationBar

%hook YTRightNavigationButtons

- (void)layoutSubviews {
    %orig;

    if (!YTMinimalUIBool(kShowMessagesButton, YES)) {
        // Property first (present since the button was introduced), identifier
        // as a fallback in case the ivar is renamed again.
        if ([self respondsToSelector:@selector(connectionsInboxButton)]) self.connectionsInboxButton.hidden = YES;
        YTMinimalUIHideSubviewWithIdentifier(self, @"id.connections.inbox.button");
    }
    if (!YTMinimalUIBool(kShowNotificationsButton, YES) && [self respondsToSelector:@selector(notificationButton)])
        self.notificationButton.hidden = YES;
    if (!YTMinimalUIBool(kShowVoiceSearchButton, YES)) {
        if ([self respondsToSelector:@selector(voiceSearchButton)]) self.voiceSearchButton.hidden = YES;
        for (UIView *subview in self.subviews) {
            if ([subview.accessibilityLabel isEqualToString:NSLocalizedString(@"search.voice.access", nil)]) subview.hidden = YES;
        }
    }
    if (!YTMinimalUIBool(kShowCastButton, YES))
        YTMinimalUIHideSubviewWithIdentifier(self, @"id.mdx.playbackroute.button");
}

%end

%end

// The microphone inside the search screen, beside the text field, which the
// top bar pass above never sees. Also from YouMod, Files/Feed.x. The
// controller decides once, in -viewDidLoad, whether voice search is offered,
// so the ivar is cleared right after it has been set. Written through the ivar
// rather than KVC: setValue:forKey: throws on a missing key, and the ivar is
// private, so on a build that renamed it the hook just does nothing.
%group gSearchVoiceButton

%hook YTSearchViewController

- (void)viewDidLoad {
    %orig;
    if (YTMinimalUIBool(kShowVoiceSearchButton, YES)) return;
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "_isVoiceSearchAllowed");
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    if (!type || (strcmp(type, @encode(BOOL)) != 0 && strcmp(type, @encode(bool)) != 0)) return;
    *(BOOL *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar)) = NO;
}

%end

%end

void YTMinimalUIInitNavigationBar(void) {
    %init(gNavigationBar);
    if (objc_getClass("YTSearchViewController")) %init(gSearchVoiceButton);
}
