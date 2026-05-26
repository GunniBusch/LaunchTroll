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

## Release Signing

GitHub Actions can build, sign, notarize, staple, and publish a `.app` zip for tags named `v*`.

Configure these repository secrets before running the release workflow:

- `APPLE_TEAM_ID`
- `DEVELOPER_ID_APPLICATION`
- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`

Configure this repository variable:

- `LAUNCHTROLL_BASE_BUNDLE_ID`

The workflow imports the Developer ID certificate into a temporary keychain, builds the app, verifies nested signatures, notarizes with `notarytool`, staples the app, and creates a GitHub Release with the final zip.
