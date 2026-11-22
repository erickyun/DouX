# Login Compatibility Mode (experimental)

This is an isolated test branch based on
`feature/hide-identity-and-music-ui-20261118`. All existing feed and comment
identity-hiding changes are preserved.

## What the mode does

**DouX Settings → Other → Login Compatibility Mode** is **ON by default**.

While ON:

- DouX's **Always Open Safari** interception is disabled. TikTok's normal
  embedded sign-in and two-factor authentication browser is allowed to run.
- DouX's **Enable Region Changing** spoofing hooks are disabled. The device's
  normal country/region values are returned to TikTok.
- The previous choices for those two switches are **not deleted**; they take
  effect again when Login Compatibility Mode is turned OFF.
- Comment/user/profile avatar hiding, @mention masking and music disc hiding
  are unchanged.

Close and reopen TikTok after changing the mode.

## How to test

1. Keep NextDNS, custom DNS filters, and any VPN or blocking configuration that
   previously broke TikTok login disabled **only for a controlled login test**.
2. Install a newly built IPA from this branch.
3. Open DouX Settings → Other and confirm Login Compatibility Mode is ON.
4. Force-close and reopen TikTok.
5. Try TikTok's **native** sign-in methods (email/password, then Google or Apple
   if supported by your app/signature). Do not repeatedly retry if TikTok says
   that too many attempts have been made.
6. Compare results with the App Store TikTok and, if necessary, the unmodified
   IPA signed using the same method.

## Limits

This mode **does not introduce a new OAuth provider**, copy Safari cookies,
bypass TikTok security checks, alter application signatures, spoof an app's
attestation, or guarantee login on a cloned/resigned IPA.

In particular, changing the Bundle ID or signing identity can break URL
callbacks, keychain access groups, associated domains, or other capabilities
required by some sign-in methods. Those requirements cannot be repaired by
the switch alone. A working sign-in also depends on TikTok's server-side
limits and the user's network/DNS configuration.

It is safest to use a separate install for testing and not merge this
experimental branch until login and existing hide features are verified on
your device.

## Login Diagnostics (experimental)

Since email/password failed too, the cause cannot be assumed to be Google's
Safari callback. This branch now includes a passive **login diagnostics** probe
without changing TikTok's authentication requests or the return arguments.

**How to collect a report (even when not signed in)**

1. Install an IPA freshly built from `feature/login-compatibility-20261122`.
2. Quit and reopen TikTok, so all probes start fresh.
3. Attempt **one** login, preferably using the method that fails most reliably.
4. Close the error popup. **Shake iPhone** to open **DouX Login Diagnostics**
   (the gesture depends on TikTok/UIWindow forwarding motion events).
   Alternatively use **DouX Settings → Other → View Login Diagnostics** if
   TikTok settings are accessible without signing in.
5. Tap **Copy Report** and paste it into the conversation. You can clear
   events afterwards.

The report stores no user identifiers, passwords, OAuth tokens, cookies,
authorization codes, or complete URLs. It lists only local lifecycle event
categories, callback presence, bundle ID/version and the number of registered
URL schemes. On-device events are retained in NSUserDefaults until cleared.

**How to interpret**

- `app_callback_received_custom-scheme`, `scene_url_callback_received`, or
  `scene_user_activity_received`: some incoming app callback was received.
  This does not guarantee TikTok accepted the login.
- `app_foregrounded` or `app_active` without an incoming callback:
  either the return was not delivered here, another callback mechanism is
  used, or the flow never reached the callback stage.
- Email/password errors can be caused by TikTok's server-side login controls,
  rate limits, network filtering, device/app integrity checks, or app signing.
  These cannot be definitively diagnosed by local callback events alone.
- If the App Store TikTok works, test a **clean unmodified decrypted TikTok
  IPA signed through exactly the same ESign flow** as DouX. This helps
  distinguish signing/bundle/entitlement issues from tweak-injection issues.
  Do not overwrite your working TikTok installation.

The probes **never** alter login parameters, move Safari cookies into TikTok,
inject session credentials, or bypass TikTok's authentication checks.

## Diagnostic update: authentication completion outcome

This branch also instruments the **completion handler** of both supported
`ASWebAuthenticationSession` initialization styles. App/scene delegate
callbacks alone are insufficient: AuthenticationServices can deliver the
result directly to its own completion handler.

Additional sanitized event categories:

- `web_auth_legacy_initializer` / `web_auth_modern_initializer`: which API started authentication.
- `web_auth_start_accepted` / `web_auth_start_rejected`: whether `start` was accepted.
- `web_auth_completed_callback_received`: a callback URL reached the
  authentication completion handler (the URL itself is **never logged**).
- `web_auth_completed_error_...`: completion failed with a numeric error
  code. No error description, credentials or URL are saved.
- `web_auth_completed_without_callback`: the handler ran without callback
  or NSError.

If login fails after `web_auth_completed_callback_received`, investigate
TikTok's own post-OAuth login exchange and signing/entitlements rather than
assuming Safari return failed. If no completion appears, compare the browser
state and the unmodified IPA before interpreting missing events.

**Report observed on 22 Nov 2026 for TikTok 47.8.0:** the older build recorded
`web_auth_session_started` and `in_app_safari_displayed`, but it did not
observe an incoming app callback. This is inconclusive because the old
diagnostics did not capture `ASWebAuthenticationSession` completion.

Use a freshly built IPA from this branch to collect a new report. Do not
interpret previous reports using these newer event categories.

## One-build comprehensive login investigation (2026-11-22)

The user has already confirmed that the Google authentication callback reaches
DouX 47.8.0. **A new Google sign-in button is not expected to fix a
server-side TikTok session refusal** and no cookie/token copying or app
attestation circumvention is attempted.

### Login Safe Mode — enabled by default on this experiment branch

**DouX Settings → Other → Login Safe Mode** temporarily suspends all ordinary
DouX preference-controlled modifications (including comment/author identity
hiding, region overrides, buttons, fake profile settings and app lock) while
you sign in. This leaves TikTok's native login logic running with fewer tweak
side effects. **The original saved DouX preferences remain intact.**

- Login Compatibility Mode stays on by default and also prevents DouX Safari
  redirects/region spoofing.
- After signing in, switch **Login Safe Mode OFF**, then fully restart TikTok
  to restore the saved comment/avatar/music hiding preferences.
- You can also switch Safe Mode directly from the **DouX Login Diagnostics**
  window, accessible by shaking the phone while logged out.
- Safe Mode suppresses preference-controlled features, but does not unload
  the injected dylib or guarantee that no unrelated hook executes.

### Run Full Check — no repeatedly collected login logs required

Open **DouX Login Diagnostics** (shake the phone or use Settings → Other).
Tap **Run Full Check**. It performs two credential-free HEAD requests to
\`https://www.tiktok.com/\` and \`https://accounts.google.com/\`, and reports:
- DNS, timeout, TLS or other connection failure, or HTTP response received.
  An HTTP response (even 403) only demonstrates network reachability; it does
  NOT prove the login APIs work or an account is accepted.
- On-device signed application identifier vs actual Bundle ID (when the
  Security framework exposes its read-only entitlement APIs).
- Presence/count of keychain-access groups, associated domains and URL callback
  schemes, without logging actual sensitive values.
- OAuth callback **parameter names only** (e.g. \`code\`, \`auth_code\`,
  \`error\`), never parameter values, state, tokens or passwords.
- HTTP status *categories* / DNS/TLS failure from matching URLSession
  TikTok/Google authentication traffic, where visible. **TikTok's private TTNet
  network stack may bypass NSURLSession, so a blank network section is not
  proof no requests happened.**
- A built-in summary prioritizing HTTP 429, connectivity issues, OAuth error,
  HTTP 401/403, successful OAuth code return and inconclusive cases.

The UI provides **Copy Report** as an optional one-off export, but shows its
own assessment and connectivity result locally so sending repeated logs is
not required. All data stays on-device until explicitly copied, and the user
can clear it. No telemetry server is used.

### Compile validation

The additional \`.github/workflows/login-compile-check.yml\` action builds
this entire tweak from source without a TikTok IPA, ensuring changes are not
left at unchecked source-only status. Its compiled DEB can be used to validate
the tweak packaging, but to install an IPA you must still use the separate
\`Create IPA Packages\` workflow and sign the IPA with ESign.

### What these changes CANNOT repair

A different Bundle ID (\`com.zhiliaoapp.musicallyx\`), signing certificate,
App ID entitlement, associated domains or keychain group can be incompatible
with TikTok's Google/account/session configuration. This experimental branch
can report clues and avoid some tweak interference, but **it cannot issue a
TikTok session for an unrecognized app, alter TikTok's server-side login
requirements, or guarantee that Google/password sign-in will work**. Do not
remove or modify your working App Store TikTok installation.

## Research findings: iOS login in sideloaded TikTok (2026-11-22)

- **ASJTok, issue #4**: a user on a non-jailbroken iPhone with Feather and a
  paid signing certificate reported that older saved TikTok accounts and new
  logins with **Save in iCloud Keychain** checked failed. Manual sign-in
  *without* saving to iCloud Keychain succeeded. The maintainer acknowledged
  that result. This is a user report, not evidence of a transferable runtime
  login-fix implementation. Source:
  https://github.com/asjrx/ASJTok/issues/4
- **Signr**: a macOS signing project states that its bundled Sideload Spoofer
  can make apps such as TikTok accept sideloaded login. Its component is a
  precompiled `SideloadSpoofer.dylib`; the source code for that component
  was not available for inspection in the repository. Do not inject opaque
  binaries automatically into this build.
  https://github.com/rursache/Signr
- **Sideload Fix**: its open source implementation redirects re-signed apps'
  keychain operations into entitled groups to address persistent-login
  problems. Its author explicitly states it does **not** fix Google, Apple
  or Facebook sign-in, and that adding a second keychain fix can cause login
  loops. Not integrated as a purported Google login fix.
  https://github.com/marioparaschiv/sideload-fix
- **Morphe/ReVanced**: Google-login-fix patches for TikTok primarily target
  Android; their package/signature/auth flows cannot be ported directly to
  this iOS Logos tweak.

### Safe workaround to try before any new patch

In DouX's TikTok login screen use **Use another account** rather than tapping
an account remembered from an earlier installation. If TikTok offers **Save in
iCloud Keychain**, leave it unchecked and decline saving the password for this
login attempt. Do not turn off or clear the iPhone's entire iCloud Keychain.

This is an independently reported workaround, not a guaranteed solution for
TikTok 47.8.0 with changed bundle identifier. If OAuth succeeds but TikTok
still refuses its own session, signing and server-side constraints remain.

### Signed App ID display

The app-side diagnostics now show **Signed App ID bundle portion** (the suffix
of the signed `application-identifier` after its prefix). This identifies
the actual signed bundle portion next to the `CFBundleIdentifier`, rather
than presenting an unexplained mismatch alone. Signed identity is determined
by the signing operation and provisioning profile, not by the `DouX` tweak.
