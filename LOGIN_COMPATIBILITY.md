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
