# CleanIdentity — standalone TikTok identity hiding

This **experimental clean branch** builds only our custom UI-hiding tweak. It
does **not** build, inject or use the original DouX tweak, ASJTok, login
diagnostics, login compatibility hooks, network modifiers, region spoofing,
downloaders or any other enhancements. The repository still contains upstream
source files, but the branch's `Makefile` compiles **only**:

- `clean_identity/identity.x`
- `clean_identity/CleanIdentityPrefs.m`

The resulting injected library is **CleanIdentity.dylib**. Its code was adapted
from the identity UI work on our earlier branch and renamed to avoid linking
the previous DouX manager.

## Features (enabled by default)

- Hide usernames displayed on videos.
- Hide video creators' avatars and follow/profile-photo widgets.
- Hide commenter/reply usernames.
- Hide comment avatars, including compact "creator liked" portrait badges.
- Remove visible `@mentions` from comment labels while preserving the
  underlying original comment text/data.
- Hide the music disc on the video UI.
- Reapply hiding when cells are first laid out, reloaded, or recycled.

Five internal `NSUserDefaults` flags default to `YES`, and there is
intentionally no extra settings panel or login injection. The tweak does not
intercept passwords, Google OAuth callbacks, app entitlements or TikTok APIs.

## Build using your OWN clean decrypted IPA

Open the workflow **Clean TikTok + Identity Only** under GitHub Actions, select
`feature/clean-tiktok-identity-only-20261122`, then click **Run workflow**.

- `ipa_url`: a direct downloadable **clean, decrypted** TikTok IPA URL, not
  DouX/ASJTok or any already-modded build. Source version such as 47.8.0 is
  read from the IPA, not hardcoded.
- `source_bundle_id`: optional — use to reject an IPA whose bundle ID isn't
  the expected clean TikTok ID; leave blank otherwise.

The workflow compiles our standalone tweak from source, checks that the input
is a TikTok IPA and contains none of the known extra third-party tweak dylibs,
then uses `ivinject` to inject **only CleanIdentity.deb**. It validates that
the app's Bundle ID and version are unchanged and that the new
`CleanIdentity.dylib` was injected. No original DouX or ASJTok library is
requested or inserted. The IPA is uploaded as a private-to-workflow GitHub
Actions artifact for you to download and sign in ESign.

Without a clean IPA URL, automatic push builds compile and validate the
standalone `.deb` only; they cannot create the final IPA.

## ESign and the App Store TikTok

To install alongside the official App Store TikTok, you may need to choose a
different Bundle ID, such as `com.zhiliaoapp.musicallyx`, **during ESign
signing**. Leave URL schemes enabled and use a certificate/provisioning profile
that authorizes the chosen App ID. Do not uninstall or overwrite the official
TikTok, and do not install over it.

Important: TikTok or Google may still reject a side-loaded, re-signed or
re-bundled application. **CleanIdentity does not bypass server-side app
identity, integrity, account restrictions or OAuth policies.** Even successful
IPA compilation is not proof that sign-in will work or every UI hook will
match the TikTok build on the user's device.

When verifying functionality, check both video and comment screens for first
render, scrolling, replies, creator-like badges and recycled cells. If a
specific UI component does not hide as expected, it may require updating the
appropriate UI hook for that TikTok version, not changing login.

This branch leaves all other experimental branches unchanged.
