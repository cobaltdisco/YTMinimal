# YTMinimal

Minimal YouTube tweak bundle with optional tweaks. Perfect for YouTube Premium subscribers who already have ad-blocking, background playback, downloads, etc.

> [!IMPORTANT]
> This tweak does not block ads.

## What's included

### Always included
- **[Open in YouTube Safari Extension](https://github.com/BillyCurtis/OpenYouTubeSafariExtension)** - Safari extension that opens YouTube links in sideloaded YouTube app.

### Optional tweaks (enabled by default, configurable in Settings)
- **[iSponsorBlock](https://github.com/JeffreyCA/iSponsorBlock)** - skips sponsor segments via the [SponsorBlock API](https://sponsor.ajay.app).
- **[DontEatMyContent](https://github.com/therealFoxster/DontEatMyContent)** - stops the notch/Dynamic Island cutting into 2:1 videos.
- **[YouChooseQuality](https://github.com/PoomSmart/YouChooseQuality)** - pins the starting video quality per connection type.
- **[YouTube Native Share](https://github.com/jkhsjdhjs/youtube-native-share)** - shares via the system sheet, without YouTube's tracking parameter.
- **YTMinimalUI** - written for this repo: OLED dark mode, navigation bar and tab bar trimming, hiding Shorts in the feed. See [its README](Tweaks/YTMinimalUI/README.md).

### Settings

Everything above is configured from a single **YTMinimal** section at the top of YouTube's own settings screen, above *Account*. Available in English and Simplified Chinese, following the app's language.

## Install

Use the `.ipa` from a release (produced by the `Build and release tweaked IPA` workflow), or resign the `.deb` against your own YouTube IPA with [`cyan`](https://github.com/asdfzxcvbn/pyzule-rw).

## Build ipa via GitHub Actions

> [!NOTE]
> If this is your first time, complete the following steps before starting:
>
> 1. Fork this repository using the fork button on the top right.
> 2. On your forked repository, go to **Repository Settings** > **Actions** > **General**, and enable **Read and write permissions** under *Workflow permissions*.

<details>
  <summary>How to build the <code>.ipa</code></summary>
  <ol>
    <li>Click <strong>Sync fork</strong>, and if your branch is out-of-date, click <strong>Update branch</strong>.</li>
    <li>Navigate to the <strong>Actions</strong> tab in your forked repository and select <strong>Build and release tweaked IPA</strong>.</li>
    <li>Click the <strong>Run workflow</strong> button on the right.</li>
    <li>
      Prepare a decrypted <code>YouTube.ipa</code> <em>(cannot be provided here for legal reasons)</em> and supply it using <strong>one</strong> of the following options:
      <ul>
        <li>
          <strong>From a direct URL:</strong> upload the IPA to a file host (e.g. filebin.net, filemail.com, Dropbox) and paste the URL into the <strong>Direct URL to a decrypted YouTube.ipa</strong> field.
          <br><strong>NOTE:</strong> Must be a direct download link, not a webpage link - otherwise the build will fail.
        </li>
        <li>
          <strong>From an existing release in your fork:</strong> upload the IPA as an asset on a release in your forked repository, then fill in both the <strong>Release tag</strong> field (e.g. <code>youtube-ipa</code>) and the <strong>Filename of the YouTube.ipa asset</strong> field (e.g. <code>YouTube.ipa</code>). Leave the direct URL field blank.
        </li>
      </ul>
    </li>
    <li>Choose whether to mark the release as a pre-release, then click <strong>Run workflow</strong> to start.</li>
    <li>When the build finishes, a <strong>draft release</strong> with the <code>.ipa</code> attached is created under the <strong>Releases</strong> section of your fork. Edit and publish it from there.</li>
  </ol>

  > **Tip:** Each optional tweak (iSponsorBlock, DontEatMyContent, YouChooseQuality, YouTube Native Share, YTMinimalUI) can be toggled on/off in the workflow inputs. All are enabled by default.
</details>

<details>
  <summary>How to build the <code>.deb</code></summary>
  <ol>
    <li>Click <strong>Sync fork</strong>, and if your branch is out-of-date, click <strong>Update branch</strong>.</li>
    <li>Navigate to the <strong>Actions</strong> tab in your forked repository and select <strong>Build deb</strong>.</li>
    <li>Click the <strong>Run workflow</strong> button on the right.</li>
    <li>Choose whether to mark the release as a pre-release, then click <strong>Run workflow</strong> to start.</li>
    <li>When the build finishes, a <strong>draft release</strong> with the <code>.deb</code> attached is created under the <strong>Releases</strong> section of your fork. Edit and publish it from there.</li>
  </ol>

  > **Tip:** Each optional tweak (iSponsorBlock, DontEatMyContent, YouChooseQuality, YouTube Native Share, YTMinimalUI) can be toggled on/off in the workflow inputs. All are enabled by default.
</details>

## Building locally

```bash
./scripts/build.sh
```

To disable specific tweaks, pass `0`:

```bash
./scripts/build.sh ENABLE_ISPONSORBLOCK=0 ENABLE_YOUCHOOSEQUALITY=0
```

To build a sideloadable IPA straight from a decrypted YouTube IPA:

```bash
./scripts/build-ipa.sh ~/Downloads/YouTube-decrypted.ipa
```

Requirements and the Theos gotchas involved are in [CLAUDE.md](CLAUDE.md).

## Casting not working?

Unfortunately you need a paid Apple dev account with an approved `com.apple.developer.networking.multicast` entitlement for native casting (see [this](https://github.com/dayanch96/YTLite/issues/334) for more info).

As a workaround, you can try:

- Using AirPlay via Control Center: see
[this comment](https://github.com/dayanch96/YTLite/issues/334#issuecomment-3490420993) for more info.

- Link with TV by going into **Settings > Watch on TV**

## Credits

All YouTube-modifying logic comes from the projects linked above. This repo only glues them together and adds some sideload fixes. Please file tweak-specific issues against the respective upstream repos.
