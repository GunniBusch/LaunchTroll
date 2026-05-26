import Foundation

struct LaunchctlClient: Sendable {
    private let executableURL: URL
    private let runner: CommandRunning

    init(
        executableURL: URL = URL(fileURLWithPath: "/bin/launchctl"),
        runner: CommandRunning = FoundationProcessRunner()
    ) {
        self.executableURL = executableURL
        self.runner = runner
    }

    func printDomain(_ domain: LaunchDomain) async throws -> String {
        try await run(["print", domain.target]).output
    }

    func printService(_ job: LaunchJob) async throws -> String {
        try await run(["print", job.domain.serviceTarget(label: job.label)]).output
    }

    func printDisabled(_ domain: LaunchDomain) async throws -> String {
        try await run(["print-disabled", domain.target]).output
    }

    func perform(_ action: LaunchAction, on job: LaunchJob) async throws {
        let arguments = Self.arguments(for: action, job: job)
        guard !arguments.isEmpty else {
            return
        }
        _ = try await run(arguments)
    }

    private func run(_ arguments: [String]) async throws -> CommandResult {
        try await runner.run(executableURL, arguments: arguments)
    }

    static func arguments(for action: LaunchAction, job: LaunchJob) -> [String] {
        let target = job.domain.serviceTarget(label: job.label)

        switch action {
        case .refresh, .revealPlist, .copyLabel:
            return []
        case .enable:
            return ["enable", target]
        case .disable:
            return ["disable", target]
        case .kickstart:
            return ["kickstart", target]
        case .restart:
            return ["kickstart", "-k", target]
        case .stop:
            return ["kill", "TERM", target]
        }
    }
}
