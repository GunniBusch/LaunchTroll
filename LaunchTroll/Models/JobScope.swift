import Foundation

enum JobScope: Hashable, Identifiable, Sendable {
    case all
    case domain(LaunchDomain)
    case running
    case disabled
    case needsAdmin

    var id: String {
        switch self {
        case .all:
            return "all"
        case .domain(let domain):
            return "domain:\(domain.id)"
        case .running:
            return "running"
        case .disabled:
            return "disabled"
        case .needsAdmin:
            return "needs-admin"
        }
    }

    var title: String {
        switch self {
        case .all:
            return "All Jobs"
        case .domain(let domain):
            return domain.sidebarName
        case .running:
            return "Running"
        case .disabled:
            return "Disabled"
        case .needsAdmin:
            return "Needs Admin"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "list.bullet"
        case .domain(let domain):
            return domain.systemImage
        case .running:
            return "play.circle"
        case .disabled:
            return "slash.circle"
        case .needsAdmin:
            return "lock.shield"
        }
    }

    var help: String {
        switch self {
        case .all:
            return "Show all launchd jobs found in scanned locations."
        case .domain(let domain):
            return "Show jobs in the \(domain.displayName) launchd domain."
        case .running:
            return "Show jobs that currently report a process identifier."
        case .disabled:
            return "Show jobs that launchd reports as disabled."
        case .needsAdmin:
            return "Show system-domain jobs that require the privileged helper for changes."
        }
    }
}
