---
name: update-submodules
description: Update the git submodules in the YTMinimal repository to their latest upstream commits. Use this when asked to update, bump, or sync the project's submodules. IMPORTANT - before updating the Tweaks/iSponsorBlock submodule, you must always ask the user to first rebase their fork (JeffreyCA/iSponsorBlock) on top of upstream (Galactic-Dev/iSponsorBlock), and you must never perform that rebase yourself.
---

# Updating YTMinimal submodules

This skill updates the git submodules declared in `.gitmodules` to the latest
commit of their tracked branch, then builds to prove the bump compiles.

The submodules are:

| Submodule | Path | Tracked branch |
| --- | --- | --- |
| YouTubeHeader | `Headers/YouTubeHeader` | `main` |
| PSHeader | `Headers/PSHeader` | `master` |
| Alderis | `Tweaks/Alderis` | pinned tag (`1.2.4`) — **ask before moving** |
| IAmYouTube | `Tweaks/IAmYouTube` | `main` |
| DontEatMyContent | `Tweaks/DontEatMyContent` | pinned tag (`v1.1.x`) — move to the latest release tag |
| YouChooseQuality | `Tweaks/YouChooseQuality` | `main` |
| youtube-native-share | `Tweaks/youtube-native-share` | pinned tag (`v0.2.x`) — move to the latest release tag |
| OpenYouTubeSafariExtension | `Extensions/OpenYouTubeSafariExtension` | `main` |
| **iSponsorBlock** | `Tweaks/iSponsorBlock` | `master` — **special handling, see below** |

## Mandatory rule for `Tweaks/iSponsorBlock`

`Tweaks/iSponsorBlock` tracks the fork <https://github.com/JeffreyCA/iSponsorBlock>,
which is a fork of the upstream <https://github.com/Galactic-Dev/iSponsorBlock>.

Before updating this submodule, you **must always**:

1. **Stop and ask the user** to first make sure `JeffreyCA/iSponsorBlock` has
   been rebased on top of `Galactic-Dev/iSponsorBlock`. You can check it
   yourself first: the fork is rebased when Galactic-Dev's `HEAD` (from
   `git ls-remote https://github.com/Galactic-Dev/iSponsorBlock HEAD`) is an
   ancestor of the fork's `master`.
2. **Never perform the rebase yourself.** Do not push, force-push, or otherwise
   modify the `JeffreyCA/iSponsorBlock` fork.
3. Only after the user confirms (or the check above shows it is rebased) should
   you update the `Tweaks/iSponsorBlock` submodule pointer.
4. If it is not rebased, update every other submodule but **skip**
   `Tweaks/iSponsorBlock` and clearly tell the user it was skipped.

The fork is rewritten by force-push on every rebase, so an old pin drops off
every branch. Do not leave it pinned to an orphaned commit for long — CI can
stop being able to fetch it.

## Procedure

1. From the repository root, initialise submodules — **never with
   `--recursive`**. The nested `Headers/YouTubeHeader` inside iSponsorBlock
   duplicates the root `Headers/` and breaks its build with `duplicate
   interface definition`. Fetch only the two nested submodules that are
   actually needed:

   ```bash
   git submodule update --init
   git -C Tweaks/DontEatMyContent submodule update --init --depth 1 YTHeaders
   git -C Tweaks/youtube-native-share submodule update --init --depth 1 protobuf
   ```

2. **Pause for iSponsorBlock** as described above.

3. Update the branch-tracking submodules (not iSponsorBlock, not the tag-pinned
   ones):

   ```bash
   git submodule update --remote -- \
     Headers/YouTubeHeader Headers/PSHeader Tweaks/IAmYouTube \
     Tweaks/YouChooseQuality Extensions/OpenYouTubeSafariExtension
   ```

   For tag-pinned submodules, `git -C <path> fetch --tags` and check out the
   newest release tag. Leave Alderis alone unless the user agrees.

4. Only if the fork is rebased, update `Tweaks/iSponsorBlock`:

   ```bash
   git submodule update --remote -- Tweaks/iSponsorBlock
   ```

5. Re-check what this repo copies out of the submodules. `Features/Settings.xm`
   in `Tweaks/YTMinimalUI` hard-codes preference keys and section ids from
   DontEatMyContent (517), YouChooseQuality (`'ycql'`) and iSponsorBlock (1081,
   `SponsorBlockSettingsController`). A rename upstream leaves a settings row
   that silently does nothing — diff the bumped submodules for those names.

6. Build from clean and confirm every dylib is in the deb:

   ```bash
   ./scripts/build.sh clean package
   dpkg-deb -c packages/*.deb | grep '\.dylib$'
   ```

7. Show the result and commit only the submodule pointers:

   ```bash
   git submodule status
   git --no-pager diff --submodule
   git add <the changed submodule paths>
   ```

   Commit with a message naming what each bump brings in. Push only if the
   user asks, and only to `origin`.

## Notes

- Always report which submodules changed and which were skipped (especially
  `Tweaks/iSponsorBlock`).
- When adding or removing a submodule, update the table above as well as the
  places listed under "Toggling tweaks" in `CLAUDE.md`.
