#import "../YTMinimalUI.h"
#import "../Headers.h"

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

void YTMinimalUIInitNavigationBar(void) {
    %init(gNavigationBar);
}
