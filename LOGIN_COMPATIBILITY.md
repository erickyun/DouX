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
