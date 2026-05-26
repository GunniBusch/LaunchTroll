# LaunchTroll

LaunchTroll is a native SwiftUI macOS utility for inspecting and controlling `launchd` jobs.

The app is intentionally built with standard macOS UI: `NavigationSplitView`, `Table`, `Form`, native toolbars, search, menus, and Settings. It scans common launchd job locations, merges conservative `launchctl` diagnostics, and keeps privileged system mutations behind a ServiceManagement helper.

## Development

Open `LaunchTroll.xcodeproj` in Xcode 26.5 or newer and select the `LaunchTroll` scheme.

Local signing is not stored in git. Configure your Apple Developer Team ID locally:

```sh
./configure_team_id.sh YOURTEAMID
```

That writes `Config/OpenSource.xcconfig`, which is ignored by git.

The app icon source lives in `LaunchTroll/AppIcon.icon`. It is an Icon Composer document named `AppIcon`, so Xcode 26 can use it as the app icon; the checked-in `AppIcon.appiconset` PNGs are exported from it with Xcode's Icon Composer `ictool` as a fallback artifact.

## Release Signing

GitHub Actions can build, sign, notarize, staple, and publish a `.app` zip for tags named `v*`.

Apple-side setup:

1. In Apple Developer, create an explicit App ID for `de.adomaitis.LaunchTroll`. A wildcard App ID such as `de.adomaitis.LaunchTroll.*` covers the privileged helper, but it does not cover the main app identifier.
2. Create a Developer ID Application certificate, download it, and export it with its private key as a password-protected `.p12`.
3. Create a Developer ID Application provisioning profile named `LaunchTrollRelease` for `de.adomaitis.LaunchTroll`.
4. In App Store Connect, create an API key with access to notarization. Team API keys also need the Issuer ID; Individual API keys do not.

Configure these repository secrets before running the release workflow:

- `APPLE_TEAM_ID`
- `DEVELOPER_ID_APPLICATION`, preferably the SHA-1 fingerprint of the Developer ID Application certificate included in `LaunchTrollRelease`
- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_PROVISION_PROFILE_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID` for Team API keys
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`

Configure this repository variable:

- `LAUNCHTROLL_BASE_BUNDLE_ID`

The workflow imports the Developer ID certificate into a temporary keychain, installs the Developer ID provisioning profile, archives the app, exports it with Developer ID export options, verifies nested signatures, notarizes with `notarytool`, staples the exported app, and publishes the final zip with `softprops/action-gh-release`.
