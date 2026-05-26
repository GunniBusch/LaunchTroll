import SwiftUI

@main
struct LaunchTrollApp: App {
    var body: some Scene {
        WindowGroup("LaunchTroll", id: "main") {
            ContentView(store: makeStore())
                .frame(minWidth: 980, minHeight: 620)
        }
        .commands {
            LaunchdCommands()
        }

        Settings {
            SettingsView()
        }
    }

    @MainActor
    private func makeStore() -> LaunchdStore {
        let environment = ProcessInfo.processInfo.environment
        if environment["LAUNCHTROLL_FAKE_DATA"] == "1" || environment["XCTestConfigurationFilePath"] != nil {
            return LaunchdStore(manager: FixtureLaunchdManager())
        }
        return LaunchdStore()
    }
}
