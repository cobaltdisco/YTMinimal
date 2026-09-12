# CLAUDE.md

Guidance for working in this repository.

## What this is

`cobaltdisco/YTMinimal` is a fork of [`JeffreyCA/YTMinimal`](https://github.com/JeffreyCA/YTMinimal),
a Theos tweak bundle for the **sideloaded** YouTube iOS app. It builds one `.deb`
containing several tweak dylibs, which is then injected into a decrypted
`YouTube.ipa` with `cyan` to produce a sideloadable IPA.

There is no jailbreak in the loop: `SideloadFixes.xm` is what makes Google
sign-in work in a resigned app, so treat it as load-bearing.

**No YouTube version is pinned.** The build injects into whatever decrypted IPA
is handed to it, so a hook cannot assume one release. Prefer hooks that fall
back to `%orig` and features that degrade to "does nothing" when a selector,
identifier or key has moved, over ones that break the app on a version they
were not written against.

`upstream` remote points at `JeffreyCA/YTMinimal`; `origin` is our fork.

## Layout

| Path | What |
| --- | --- |
| `Makefile` | Root aggregate project; picks which subprojects build |
| `control` | Package metadata (id, version) — the version drives release tags |
| `SideloadFixes.xm` | Keychain / access-group fixes for a resigned YouTube |
| `Tweaks/*` (submodules) | Third-party tweaks, vendored as git submodules |
| `Tweaks/YTMinimalUI/Features/Settings.xm` | The one settings section, above Account |
| `Tweaks/YTMinimalUI` | **Our own interface tweaks** — new features go here |
| `Headers/YouTubeHeader` | PoomSmart's YouTube class headers (on the include path) |
| `Extensions/OpenYouTubeSafariExtension` | Prebuilt `.appex` injected alongside the deb |
| `scripts/` | Local build wrappers, mirroring the GitHub Actions workflows |
| `.github/workflows/` | `build-deb.yml` and `build-ipa.yml`, both `workflow_dispatch` |

## Building locally

```bash
./scripts/build.sh                                  # .deb into packages/
./scripts/build.sh ENABLE_ISPONSORBLOCK=0           # any ENABLE_* flag
./scripts/build.sh clean package                    # extra make targets pass through
./scripts/build-ipa.sh ~/Downloads/<decrypted>.ipa  # .deb + inject -> YTMinimal_<version>.ipa
```

A full build takes well under a minute. Requirements, all already installed on
this machine: Theos at `~/theos`, `iPhoneOS16.5.sdk` in `~/theos/sdks`, Homebrew
`make` / `ldid` / `dpkg`, and `cyan` (pyzule-rw) via pipx for the IPA step.

### Theos gotchas — these will bite

- **GNU make 4 is required.** macOS ships make 3.81, which cannot parse Theos'
  makefiles. `scripts/env.sh` puts `$(brew --prefix make)/libexec/gnubin` first
  on `PATH`; if you invoke `make` by hand, do the same.
- **Never clone submodules recursively.** `Tweaks/iSponsorBlock` has its own
  nested `Headers/YouTubeHeader` submodule. The root Makefile already puts
  `Headers/` on the include path, so if the nested copy is checked out, every
  YouTube class gets declared twice and iSponsorBlock fails to compile with
  `duplicate interface definition`. CI uses `submodules: true` (non-recursive)
  for exactly this reason. Clone with:

  ```bash
  git submodule update --init          # not --recursive
  ```

  If it was already cloned recursively:

  ```bash
  git -C Tweaks/iSponsorBlock submodule deinit -f Headers/YouTubeHeader
  ```

- **But two nested submodules *are* required**, and a non-recursive checkout
  does not fetch them — this is what breaks CI when it is missing, as
  `Tweaks/DontEatMyContent` fails on `'YTHeaders/YTPlayerViewController.h' file
  not found`. Both workflows have a "Fetch the two nested submodules" step for
  it; `scripts/env.sh` does not do this for you:

  ```bash
  git -C Tweaks/DontEatMyContent submodule update --init --depth 1 YTHeaders
  git -C Tweaks/youtube-native-share submodule update --init --depth 1 protobuf
  ```

  Neither collides with `Headers/`: DontEatMyContent imports `<YTHeaders/…>` and
  youtube-native-share only wants protobuf's Objective-C headers.
  `Tweaks/YouChooseQuality` needs no nested submodule — it imports
  `<YouTubeHeader/…>` and `<PSHeader/…>`, which the root `Headers/` provides.

- **logos drops the closing brace when `%orig;` and `}` share a line.** This bit
  is real and cost an hour: `- (id)foo { return %orig; }` compiles to a function
  with no closing brace, and clang reports `function definition is not allowed
  here` on a *later* line. Always write such bodies over three lines. Likewise
  `f(%orig)` as a call argument fails to parse — assign `%orig` to a local first.

- The SDK is pinned to **16.5** and the deployment target to **13.0**. Xcode's
  own newer SDK is used for the Alderis framework subproject; that is expected.
- Alderis builds through `xcodebuild` and is the slow part of a clean build. Its
  framework is bundled into the deb via `iSponsorBlock_EMBED_FRAMEWORKS` in the
  root Makefile.

## Toggling tweaks

Every optional tweak is an `ENABLE_*` flag in the root Makefile, defaulting to
`1`, mirrored as a `workflow_dispatch` boolean input in both workflows:

| Flag | Subprojects |
| --- | --- |
| `ENABLE_ISPONSORBLOCK` | `Tweaks/Alderis`, `Tweaks/iSponsorBlock` |
| `ENABLE_DONTEATMYCONTENT` | `Tweaks/DontEatMyContent` |
| `ENABLE_YOUCHOOSEQUALITY` | `Tweaks/YouChooseQuality` |
| `ENABLE_NATIVESHARE` | `Tweaks/youtube-native-share` |
| `ENABLE_YTMINIMALUI` | `Tweaks/YTMinimalUI` |

`Tweaks/YTMinimalUI` must stay last in `SUBPROJECTS`.

**When adding or removing a tweak, change all three places:** the root Makefile
(flag + `SUBPROJECTS`), and the `inputs:` block plus the `make package` line in
*both* `.github/workflows/build-deb.yml` and `build-ipa.yml`.

## Where new features go

New interface behaviour belongs in **`Tweaks/YTMinimalUI`**, not in a YTLite
submodule and not in the root `YTMinimal` tweak (which is reserved for sideload
fixes and `IAmYouTube`). YTLite was deliberately not adopted: it ships no
licence, carries its own sideloading fixes that collide with `SideloadFixes.xm`,
and would drag in hundreds of unrelated options. **uYouEnhanced is off limits
for the same reason** — it has no LICENSE file at all. Where its behaviour is
wanted, take the equivalent from YouMod (GPL-3.0, compatible with this repo) and
record it in `NOTICE`.

See `Tweaks/YTMinimalUI/README.md` for the one-file-per-feature pattern.

### The settings screen

YouTube's settings are two levels deep: `+[YTAppSettingsGroupPresentationData
orderedGroups]` lists **group** types (Account, Video and audio preferences,
Help and policies), and each group holds ordered **categories**, where a
category is one titled section. Every other tweak pushes its category into the
Account group (type 1), which is why they all look like part of Account.

`Features/Settings.xm` registers a group of its own, titled `YTMinimal`, first
in `orderedGroups`. The group title is the big native heading; the single
category under it hides its own header and holds one row, `Tweaks`, carrying the
`YT_TUNE` sliders icon. Three levels in total:

```
YTMinimal                 ← group title
  [icon] Tweaks           → Appearance / Navigation bar / Tab bar
                            / Shorts / Video play / About
                              → the switches for each
```

Switches are phrased as **Show**, defaulting to on, so every one of them reads
the same way round.

`Tweaks/DontEatMyContent`, `Tweaks/YouChooseQuality` and `Tweaks/iSponsorBlock`
each register a section of their own (ids 517, `'ycql'` and 1081). Those
registrations are swallowed in `-[YTSettingsViewController
setSectionItems:forCategory:…]` — deterministic, unlike filtering the category
lists, which depends on hook order. Each gets a row under Video play instead:
the first two open a sub-page built from **their own bundle's strings**, and
iSponsorBlock opens its own `SponsorBlockSettingsController`.

Two consequences worth knowing:

- **When bumping those submodules, re-check the preference keys and section ids
  copied at the top of `Features/Settings.xm`** — a rename leaves a row that
  silently does nothing.
- The ordering hooks are `%init`ed from a `dispatch_async` to the main queue, not
  from `%ctor`, so they install *after* every other tweak's and get the last word
  on the order. Do not move them back into `%ctor`.

### The row-0 trap

`YTSettingsPickerViewController` doubles as a generic sub-page when handed
non-checkmark rows, and that is how all the pages below `Tweaks` are built. It
still treats `selectedItemIndex` as a **row index and marks that row as
chosen** — so on a page of switches, `selectedItemIndex:0` silently forces the
first switch on every time the page opens, no matter what the preference says.
The switch then lies about a setting that is actually off.

The index is forwarded to `-[YTSettingsSectionController setSelectedItem:]`,
which is where `Features/Settings.xm` intercepts it: **selection is dropped when
the target row carries a switch**, since only a checkmark list has a meaningful
selection. That keeps the pages free of a dummy row at index 0 (the usual
workaround, and why YouMod's pages all start with a heading) without passing
`NSNotFound` as an index, which is not obviously safe.

Checkmark pickers are the intended use of `selectedItemIndex` and pass through
untouched.

### How the OLED pass reaches ELM-drawn views

`Features/Appearance.xm` has two halves. The palette hooks (`YTColor`,
`YTCommonColorPalette`) cover everything YouTube colours through its own theme;
sheets, chip bars, the comment composer, panel footers and live chat set a
near-black background on the view instead, so each is painted by hand.

Those views are all `_ASDisplayView` (AsyncDisplayKit) with an opaque ELM
renderer behind them, so **the accessibility identifier is the only stable
handle** — `id.elements.components.filter_chip_bar`, `eml.chip_bar_collection`,
and so on. Where the identifier is not enough to tell a sheet from the feed
behind it, `-[UIView _viewControllerForAncestor]` says which screen the view
landed on.

Two things follow from that:

- An identifier that does not match fails silently: the surface just stays grey.
  Nothing crashes, which is the property to keep given the YouTube version
  floats. A report of "this bit is still grey" means an identifier to re-check
  against that build, not a bug.
- The same identifiers are the only view-level handle on ELM content in general.
  Removing views this way is a different matter — it happens after layout, and
  `_ASCollectionViewCell` is recycled, so a gutted cell comes back blank. Read
  is safe; write is not.

### How subtitles are pinned

`Features/Subtitles.xm` hooks exactly one getter,
`-[MLCaptionConfigImpl captionVisibility]`. That class is where YouTube keeps
the caption toggle you last made while watching (persisted as
`user.persistent_user_caption_visibility`), and the per-video loader reads it
back in `-[MLInnerTubeCaptionController loadUserCaptionsWithSelectionReason:]`
and `-loadUserCaptionsBasedOnPastUserSelectionWithSelectionReason:`. Its values
are `0` unset (defer to the iOS *Closed Captions + SDH* switch), `1` shown,
`2` hidden.

The CC button in the player goes through
`-[MLInnerTubeCaptionController setSelectedCaptionTrack:selectionReason:]`,
which loads the track directly and never reads the visibility back — so forcing
the getter pins what each new video starts with without breaking the toggle for
the video already playing.

Two paths still win over the setting, by design: a video whose player response
declares `CaptionsInitialState…Required`, and a forced caption track. Those are
the cases where the publisher requires captions.

PoomSmart's YouRememberCaption is *not* usable here — it stopped working at
YouTube 20.16.7, and `respectDeviceCaptionSetting` no longer exists in 21.32.4.

## Releasing

Both workflows are manual (`workflow_dispatch`) and create **draft** releases
tagged from the `Version:` line in `control`. Bump `control` before dispatching.
`build-ipa.yml` needs either a direct `ipa_url` to a decrypted YouTube IPA or a
`release_tag` + `artifact_filename` pointing at one already attached to a release
in this repo.

Both also attach `YTMinimal_<version>_dSYMs.zip`, the debug symbols for every
dylib in that build — keep the one matching a release around, or a crash report
from it can never be symbolicated. Nothing has to be passed to `make` for this:
Theos runs `dsymutil` on each link *before* it strips, so `FINALPACKAGE=1`
already leaves a `.dSYM` beside every dylib in `.theos/obj/arm64`, and Alderis'
lands in its xcarchive. The collect step fails the build if it finds none.

## Conventions

- Match the existing code: Objective-C with Logos (`.xm`/`.x`), ARC on, hooks
  wrapped in `%group` and `%init`ed conditionally.
- Do not commit build output — `packages/`, `*.deb`, `*.ipa` and `.theos/` are
  ignored.
- Submodule bumps have a dedicated skill at `.github/skills/update-submodules/`;
  it requires asking before touching `Tweaks/iSponsorBlock`.
