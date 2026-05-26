import Foundation

enum LaunchJobSourceLocation: String, CaseIterable, Codable, Sendable {
    case systemLaunchAgent = "/System/Library/LaunchAgents"
    case systemLaunchDaemon = "/System/Library/LaunchDaemons"
    case localLaunchAgent = "/Library/LaunchAgents"
    case localLaunchDaemon = "/Library/LaunchDaemons"
    case userLaunchAgent = "~/Library/LaunchAgents"
    case launchctl = "launchctl"

    var displayName: String {
        rawValue
    }
}

struct LaunchJob: Identifiable, Hashable, Sendable {
    let id: String
    var label: String
    var domain: LaunchDomain
    var plistURL: URL?
    var sourceLocation: LaunchJobSourceLocation
    var disabled: Bool?
    var pid: Int?
    var lastExitStatus: Int?
    var rawStatus: String?
    var program: String?
    var programArguments: [String]
    var keepAliveDescription: String?
    var runAtLoad: Bool?

    init(
        label: String,
        domain: LaunchDomain,
        plistURL: URL? = nil,
        sourceLocation: LaunchJobSourceLocation,
        disabled: Bool? = nil,
        pid: Int? = nil,
        lastExitStatus: Int? = nil,
        rawStatus: String? = nil,
        program: String? = nil,
        programArguments: [String] = [],
        keepAliveDescription: String? = nil,
        runAtLoad: Bool? = nil
    ) {
        self.id = LaunchJob.makeID(label: label, domain: domain)
        self.label = label
        self.domain = domain
        self.plistURL = plistURL
        self.sourceLocation = sourceLocation
        self.disabled = disabled
        self.pid = pid
        self.lastExitStatus = lastExitStatus
        self.rawStatus = rawStatus
        self.program = program
        self.programArguments = programArguments
        self.keepAliveDescription = keepAliveDescription
        self.runAtLoad = runAtLoad
    }

    var isRunning: Bool {
        if let pid {
            return pid > 0
        }
        return false
    }

    var stateDescription: String {
        if disabled == true {
            return "Disabled"
        }
        if isRunning {
            return "Running"
        }
        if pid == 0 || lastExitStatus != nil {
            return "Not Running"
        }
        return "Unknown"
    }

    var statusDetail: String {
        if let pid, pid > 0 {
            return "PID \(pid)"
        }
        if let lastExitStatus {
            return "Last exit \(lastExitStatus)"
        }
        return stateDescription
    }

    var canMutateWithoutAdmin: Bool {
        !domain.requiresAdministrator
    }

    var isAppleProvided: Bool {
        label.hasPrefix("com.apple.")
            || sourceLocation == .systemLaunchAgent
            || sourceLocation == .systemLaunchDaemon
    }

    static func makeID(label: String, domain: LaunchDomain) -> String {
        "\(domain.target)::\(label)"
    }
}
