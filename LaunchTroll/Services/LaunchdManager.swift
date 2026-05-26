import Foundation

protocol LaunchdManaging: Sendable {
    func loadJobDefinitions() async throws -> [LaunchJob]
    func loadJobs() async throws -> [LaunchJob]
    func loadDetails(for job: LaunchJob) async throws -> LaunchJob
    func perform(_ action: LaunchAction, on job: LaunchJob) async throws
}

extension LaunchdManaging {
    func loadJobDefinitions() async throws -> [LaunchJob] {
        try await loadJobs()
    }
}

struct LiveLaunchdManager: LaunchdManaging {
    private let scanner: PropertyListJobScanner
    private let launchctl: LaunchctlClient
    private let domains: [LaunchDomain]

    init(
        scanner: PropertyListJobScanner = PropertyListJobScanner(),
        launchctl: LaunchctlClient = LaunchctlClient(),
        domains: [LaunchDomain] = LaunchDomain.currentUserDomains
    ) {
        self.scanner = scanner
        self.launchctl = launchctl
        self.domains = domains
    }

    func loadJobDefinitions() async throws -> [LaunchJob] {
        sortedJobs(mergeByID(await scanner.scan()))
    }

    func loadJobs() async throws -> [LaunchJob] {
        var jobsByID = mergeByID(await scanner.scan())

        for domain in domains {
            let serviceStatuses = await serviceStatuses(for: domain)
            for status in serviceStatuses.values {
                let id = LaunchJob.makeID(label: status.label, domain: domain)
                guard var job = jobsByID[id] else {
                    continue
                }
                job.pid = status.pid
                job.lastExitStatus = status.lastExitStatus
                jobsByID[id] = job
            }

            let disabledServices = await disabledServices(for: domain)
            for (label, disabled) in disabledServices {
                let id = LaunchJob.makeID(label: label, domain: domain)
                guard var job = jobsByID[id] else {
                    continue
                }
                job.disabled = disabled
                jobsByID[id] = job
            }
        }

        return sortedJobs(jobsByID)
    }

    private func mergeByID(_ jobs: [LaunchJob]) -> [String: LaunchJob] {
        var jobsByID: [String: LaunchJob] = [:]
        for job in jobs {
            jobsByID[job.id] = job
        }
        return jobsByID
    }

    private func sortedJobs(_ jobsByID: [String: LaunchJob]) -> [LaunchJob] {
        jobsByID.values.sorted {
            if $0.domain.target == $1.domain.target {
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return $0.domain.target < $1.domain.target
        }
    }

    func loadDetails(for job: LaunchJob) async throws -> LaunchJob {
        var detailedJob = job
        detailedJob.rawStatus = await serviceDiagnostic(for: job)
        return detailedJob
    }

    func perform(_ action: LaunchAction, on job: LaunchJob) async throws {
        try await launchctl.perform(action, on: job)
    }

    private func serviceStatuses(for domain: LaunchDomain) async -> [String: LaunchctlServiceStatus] {
        do {
            let output = try await launchctl.printDomain(domain)
            return Dictionary(
                LaunchctlOutputParser.parseServices(from: output).map { ($0.label, $0) },
                uniquingKeysWith: { current, _ in current }
            )
        } catch {
            return [:]
        }
    }

    private func serviceDiagnostic(for job: LaunchJob) async -> String {
        do {
            return try await launchctl.printService(job)
        } catch {
            return """
            Live launchd diagnostics unavailable.

            \(diagnosticMessage(for: error))
            """
        }
    }

    private func diagnosticMessage(for error: Error) -> String {
        if case CommandRunnerError.nonZeroExit(_, _, let result) = error {
            let message = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                return message
            }
        }

        return error.localizedDescription
    }

    private func disabledServices(for domain: LaunchDomain) async -> [String: Bool] {
        do {
            let output = try await launchctl.printDisabled(domain)
            return LaunchctlOutputParser.parseDisabledServices(from: output)
        } catch {
            return [:]
        }
    }
}

struct FixtureLaunchdManager: LaunchdManaging {
    func loadJobs() async throws -> [LaunchJob] {
        [
            LaunchJob(
                label: "com.example.user-agent",
                domain: .gui(uid: getuid()),
                plistURL: URL(fileURLWithPath: "/Users/example/Library/LaunchAgents/com.example.user-agent.plist"),
                sourceLocation: .userLaunchAgent,
                disabled: false,
                pid: 4281,
                programArguments: ["/usr/bin/open", "-gj", "/Applications/Example.app"],
                keepAliveDescription: "On demand",
                runAtLoad: true
            ),
            LaunchJob(
                label: "com.example.disabled",
                domain: .gui(uid: getuid()),
                plistURL: URL(fileURLWithPath: "/Library/LaunchAgents/com.example.disabled.plist"),
                sourceLocation: .localLaunchAgent,
                disabled: true,
                programArguments: ["/usr/local/bin/example-disabled"]
            ),
            LaunchJob(
                label: "com.example.system-daemon",
                domain: .system,
                plistURL: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.system-daemon.plist"),
                sourceLocation: .localLaunchDaemon,
                disabled: false,
                pid: nil,
                programArguments: ["/usr/local/sbin/exampled"],
                keepAliveDescription: "Always"
            )
        ]
    }

    func loadDetails(for job: LaunchJob) async throws -> LaunchJob {
        var job = job
        job.rawStatus = """
        \(job.domain.serviceTarget(label: job.label)) = {
            active count = \(job.isRunning ? 1 : 0)
            path = \(job.plistURL?.path ?? "unknown")
            state = \(job.stateDescription)
        }
        """
        return job
    }

    func perform(_ action: LaunchAction, on job: LaunchJob) async throws {
        _ = action
        _ = job
    }
}
