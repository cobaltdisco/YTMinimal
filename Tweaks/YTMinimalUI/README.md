# YTMinimalUI

The interface tweaks written for this fork, as opposed to the third-party tweaks
vendored under `Tweaks/` as submodules. It also owns the single settings section
this bundle shows in YouTube's own settings screen.

## Layout

| File | What |
| --- | --- |
| `Tweak.xm` | `%ctor` only; calls each feature's initialiser |
| `YTMinimalUI.h` | Preference keys and accessors, localisation macro, feature initialiser declarations |
| `Headers.h` | Declarations for YouTube classes `Headers/YouTubeHeader` does not cover |
| `Features/Appearance.xm` | OLED dark mode |
| `Features/NavigationBar.xm` | Hiding top bar buttons, including the Messages button |
| `Features/TabBar.xm` | Which tabs the bottom bar shows, labels, launch tab |
| `Features/Shorts.xm` | Dropping the Shorts shelf from the feed |
| `Features/Settings.xm` | The `YTMinimal` settings group and its six categories |
| `layout/…/YTMinimalUI.bundle` | `en` and `zh-Hans` strings |

## Adding a feature

1. Create `Features/<Name>.xm`:

   ```objc
   #import "../YTMinimalUI.h"
   #import "../Headers.h"

   %group gName
   // %hook … your hooks
   %end

   void YTMinimalUIInitName(void) {
       if (!YTMinimalUIBool(kSomeKey, YES)) return;
       %init(gName);
   }
   ```

2. Add the preference key to `YTMinimalUI.h` and declare `YTMinimalUIInitName`.
3. Call it from `%ctor` in `Tweak.xm`.
4. Add a row in `Features/Settings.xm` and strings to both `.lproj` files.

The Makefile globs `Features/*.xm`, so there is nothing else to register.

## Two things that will trip you up

**Never put `%orig` and the closing `}` on the same line.** This Theos' logos
drops the brace and you get a confusing `function definition is not allowed
here` from a line further down. Write the body over three lines instead.

**Never pass `%orig` straight into a function call** (`f(%orig)`) — assign it to
a local first. Same parser, same class of failure.

## Preferences

Plain `NSUserDefaults` keys in the YouTube app's own domain, prefixed
`YTMinimalUI`. `Features/Settings.xm` additionally reads and writes the keys
owned by `Tweaks/DontEatMyContent` and `Tweaks/YouChooseQuality`, and localises
their rows from *their* bundles rather than ours, so the wording stays
identical to upstream. Those key names and section ids are copied at the top of
that file and must be re-checked when the submodules are bumped.

## Settings structure

See CLAUDE.md for how the group/category model works. In short: we own a group
called `YTMinimal` placed above Account, containing Appearance, Navigation bar,
Tab bar, Shorts, Video play and About. Video play holds one row per third-party
tweak, each opening that tweak's own settings.
