import SwiftUI

struct LaunchdCommandActions {
    var refresh: @MainActor () -> Void
    var performSelected: @MainActor (LaunchAction) -> Void
    var canPerformSelected: @MainActor (LaunchAction) -> Bool
}

private struct LaunchdCommandActionsKey: FocusedValueKey {
    typealias Value = LaunchdCommandActions
}

extension FocusedValues {
    var launchdCommandActions: LaunchdCommandActions? {
        get { self[LaunchdCommandActionsKey.self] }
        set { self[LaunchdCommandActionsKey.self] = newValue }
    }
}

struct LaunchdCommands: Commands {
    @FocusedValue(\.launchdCommandActions) private var actions

    var body: some Commands {
        CommandMenu("Launchd") {
            Button("Refresh") {
                actions?.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(actions == nil)

            Divider()

            Button("Start") {
                actions?.performSelected(.kickstart)
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(actions?.canPerformSelected(.kickstart) != true)

            Button("Restart") {
                actions?.performSelected(.restart)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(actions?.canPerformSelected(.restart) != true)

            Button("Stop") {
                actions?.performSelected(.stop)
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(actions?.canPerformSelected(.stop) != true)

            Divider()

            Button("Copy Label") {
                actions?.performSelected(.copyLabel)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(actions?.canPerformSelected(.copyLabel) != true)
        }
    }
}
