# Development

LaunchTroll uses the same local-signing pattern as open source macOS projects such as Secretive:

1. The repository checks in `Config/Config.xcconfig`.
2. `Config/Config.xcconfig` optionally includes `Config/OpenSource.xcconfig`.
3. `Config/OpenSource.xcconfig` is generated locally and ignored by git.

Configure your local Apple Developer team once:

```sh
./configure_team_id.sh YOURTEAMID
```

For this checkout, `Config/OpenSource.xcconfig` has been generated locally with the current Apple Developer team. The checked-in project resolves `DEVELOPMENT_TEAM` from `$(LAUNCHTROLL_DEVELOPMENT_TEAM)`, so contributors can use their own team IDs without changing `LaunchTroll.xcodeproj/project.pbxproj`.

To verify signing resolution:

```sh
xcodebuild -project LaunchTroll.xcodeproj -target LaunchTroll -configuration Debug -showBuildSettings | rg "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER"
xcodebuild -project LaunchTroll.xcodeproj -target LaunchTroll.PrivilegedHelper -configuration Debug -showBuildSettings | rg "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER"
```
