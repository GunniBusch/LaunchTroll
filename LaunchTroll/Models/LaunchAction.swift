import Foundation

enum LaunchAction: String, CaseIterable, Identifiable, Sendable {
    case refresh
    case enable
    case disable
    case kickstart
    case restart
    case stop
    case revealPlist
    case copyLabel

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .refresh:
            return "Refresh"
        case .enable:
            return "Enable"
        case .disable:
            return "Disable"
        case .kickstart:
            return "Start"
        case .restart:
            return "Restart"
        case .stop:
            return "Stop"
        case .revealPlist:
            return "Reveal Plist"
        case .copyLabel:
            return "Copy Label"
        }
    }

    var systemImage: String {
        switch self {
        case .refresh:
            return "arrow.clockwise"
        case .enable:
            return "checkmark.circle"
        case .disable:
            return "slash.circle"
        case .kickstart:
            return "play.fill"
        case .restart:
            return "arrow.clockwise.circle"
        case .stop:
            return "stop.fill"
        case .revealPlist:
            return "doc.text.magnifyingglass"
        case .copyLabel:
            return "doc.on.doc"
        }
    }

    var help: String {
        switch self {
        case .refresh:
            return "Reload launchd jobs and disabled state."
        case .enable:
            return "Enable the selected launchd job."
        case .disable:
            return "Disable the selected launchd job."
        case .kickstart:
            return "Ask launchd to start the selected job."
        case .restart:
            return "Stop and start the selected launchd job."
        case .stop:
            return "Send TERM to the selected launchd job."
        case .revealPlist:
            return "Reveal the selected job plist in Finder."
        case .copyLabel:
            return "Copy the selected launchd label."
        }
    }
}
