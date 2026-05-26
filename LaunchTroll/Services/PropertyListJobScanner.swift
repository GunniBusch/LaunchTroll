import Foundation

struct LaunchJobScanLocation: Hashable, Sendable {
    var directoryURL: URL
    var domain: LaunchDomain
    var sourceLocation: LaunchJobSourceLocation
}

struct PropertyListJobScanner: Sendable {
    private let fileManager: FileManager
    private let locations: [LaunchJobScanLocation]

    init(
        fileManager: FileManager = .default,
        locations: [LaunchJobScanLocation]? = nil,
        uid: uid_t = getuid()
    ) {
        self.fileManager = fileManager
        self.locations = locations ?? Self.defaultLocations(uid: uid)
    }

    func scan() async -> [LaunchJob] {
        locations.flatMap { scan(location: $0) }
            .sorted {
                if $0.domain.target == $1.domain.target {
                    return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                }
                return $0.domain.target < $1.domain.target
            }
    }

    private func scan(location: LaunchJobScanLocation) -> [LaunchJob] {
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: location.directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return files
            .filter { $0.pathExtension == "plist" }
            .compactMap { makeJob(from: $0, location: location) }
    }

    private func makeJob(from url: URL, location: LaunchJobScanLocation) -> LaunchJob? {
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dictionary = plist as? [String: Any],
            let label = dictionary["Label"] as? String,
            !label.isEmpty
        else {
            return nil
        }

        let programArguments = dictionary["ProgramArguments"] as? [String] ?? []
        let program = dictionary["Program"] as? String
        let disabled = dictionary["Disabled"] as? Bool
        let runAtLoad = dictionary["RunAtLoad"] as? Bool
        let keepAliveDescription = describeKeepAlive(dictionary["KeepAlive"])

        return LaunchJob(
            label: label,
            domain: location.domain,
            plistURL: url,
            sourceLocation: location.sourceLocation,
            disabled: disabled,
            program: program,
            programArguments: programArguments,
            keepAliveDescription: keepAliveDescription,
            runAtLoad: runAtLoad
        )
    }

    private func describeKeepAlive(_ value: Any?) -> String? {
        switch value {
        case let bool as Bool:
            return bool ? "Always" : "On demand"
        case let dictionary as [String: Any]:
            if dictionary.isEmpty {
                return nil
            }
            return dictionary.keys.sorted().joined(separator: ", ")
        default:
            return nil
        }
    }

    static func defaultLocations(uid: uid_t = getuid()) -> [LaunchJobScanLocation] {
        [
            LaunchJobScanLocation(
                directoryURL: URL(fileURLWithPath: "/System/Library/LaunchAgents"),
                domain: .gui(uid: uid),
                sourceLocation: .systemLaunchAgent
            ),
            LaunchJobScanLocation(
                directoryURL: URL(fileURLWithPath: "/System/Library/LaunchDaemons"),
                domain: .system,
                sourceLocation: .systemLaunchDaemon
            ),
            LaunchJobScanLocation(
                directoryURL: URL(fileURLWithPath: "/Library/LaunchAgents"),
                domain: .gui(uid: uid),
                sourceLocation: .localLaunchAgent
            ),
            LaunchJobScanLocation(
                directoryURL: URL(fileURLWithPath: "/Library/LaunchDaemons"),
                domain: .system,
                sourceLocation: .localLaunchDaemon
            ),
            LaunchJobScanLocation(
                directoryURL: FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/LaunchAgents", isDirectory: true),
                domain: .gui(uid: uid),
                sourceLocation: .userLaunchAgent
            )
        ]
    }
}
