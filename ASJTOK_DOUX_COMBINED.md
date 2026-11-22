# Experimental ASJTok + DouX combined build

This branch starts from `feature/login-compatibility-20261122` and retains the
current DouX features: hidden video/comment usernames, avatars, mentions, creator
liked-badges, music disc, plus login compatibility and on-device diagnostics.

## What was actually verified

The [ASJTok GitHub repository](https://github.com/asjrx/ASJTok) publishes an
official, pre-compiled ASJTok IPA and .dylib, but **does not contain the tweak's
source code**. Thus we **cannot transplant a proven ASJTok "Google login fix"**
into DouX. The successful [GitHub issue #4](https://github.com/asjrx/ASJTok/issues/4)
was a user's workaround: manually sign into a NEW account rather than a saved
account and *do not* enable "Save in iCloud Keychain." It wasn't a published
patch or a guarantee about TikTok 47.8.0.

This project provides a way for the user to combine *their own experimental
DouX build* with the developer's *official publicly released ASJTok build*, or
to inject both official ASJTok's prebuilt dylib and DouX into their existing
decrypted TikTok IPA. We do **not** claim to own ASJTok, distribute its source,
or automatically push the combined binary as a public GitHub release.

## How to build

Run the GitHub Actions workflow **ASJTok + DouX Combined IPA** on
`feature/asjtok-doux-combined-20261122`.

Choose one mode:

1. **official_asjtok_47_6** — default; downloads official
   `ASJTok-1.4.1_47.6.0.ipa` from its author's GitHub release, builds the
   latest DouX tweak from *this* branch, and injects DouX into that ASJTok IPA.
   **Source TikTok version is 47.6.0**, not the user's existing **47.8.0**.
   This is the best-aligned option for ASJTok's released implementation.
2. **custom_tiktok_with_asjtok** — requires the user's decrypted TikTok IPA URL;
   combines this branch's DouX with official
   `ASJTok-1.4.1_47.6.0.dylib`. The ASJTok dylib was published against TikTok
   47.6.0 and **may crash or fail when injected into TikTok 47.8.0**.

The workflow validates that the base and combined versions and bundle IDs are
unchanged and that both tweak dylibs are present in the resulting archive.
It deliberately does not automatically publish the modified IPA as a GitHub
release. Download the GitHub Actions **artifact**, then sign it using an
authorized certificate/profile in ESign.

## Logging in

- Open TikTok's **Use another account** / manual login flow, avoiding a
  previously remembered account.
- If TikTok prompts to **Save in iCloud Keychain**, do not select it for the
  initial login experiment. Do not clear or turn off the phone's entire iCloud
  Keychain.
- The inherited **Login Safe Mode** is ON by default and temporarily suppresses
  DouX's preference-controlled hooks for first login. After successful login,
  switch it OFF in DouX settings and restart TikTok to restore the hidden
  names, avatars, mentions and music options.

## Limitations and caution

- A successful build **does not prove ASJTok and DouX coexist safely**. Both
  alter TikTok's runtime and may hook overlapping selectors. The combined build
  has not been tested on a user's iPhone.
- Keeping App Store TikTok installed simultaneously normally requires a
  **different Bundle ID**, and iOS/TikTok/Google login may reject such a
  re-bundled, re-signed app. Combining ASJTok with DouX **cannot guarantee**
  Google sign-in works with `com.zhiliaoapp.musicallyx`.
- Do not overwrite or uninstall the working App Store TikTok. If signing the
  combined IPA requires the same Bundle ID as the App Store copy, stop before
  installation rather than replacing it.
- The latest ASJTok source available is *precompiled*. Do not assume its
  license permits copying internal code or distributing derivative packages.
- Neither authentication token copying nor bypassing Google/TikTok security
  checks is performed.
