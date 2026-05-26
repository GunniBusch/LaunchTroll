import Foundation

enum LaunchDomain: Hashable, Identifiable, Codable, Sendable {
    case system
    case user(uid: uid_t)
    case gui(uid: uid_t)

    var id: String {
        target
    }

    var target: String {
        switch self {
        case .system:
            return "system"
        case .user(let uid):
            return "user/\(uid)"
        case .gui(let uid):
            return "gui/\(uid)"
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .user(let uid):
            return "User \(uid)"
        case .gui(let uid):
            return "GUI \(uid)"
        }
    }

    var sidebarName: String {
        switch self {
        case .system:
            return "System"
        case .user:
            return "User"
        case .gui:
            return "GUI"
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            return "server.rack"
        case .user:
            return "person"
        case .gui:
            return "macwindow"
        }
    }

    var requiresAdministrator: Bool {
        self == .system
    }

    func serviceTarget(label: String) -> String {
        "\(target)/\(label)"
    }

    static var currentUserDomains: [LaunchDomain] {
        let uid = getuid()
        return [.system, .gui(uid: uid), .user(uid: uid)]
    }
}
