import Foundation
import Testing
@testable import LaunchTroll

struct LaunchTrollTests {
    @Test func scansLaunchdPlistFixtures() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let plistURL = directory.appendingPathComponent("com.example.agent.plist")
        let plist: [String: Any] = [
            "Label": "com.example.agent",
            "ProgramArguments": ["/usr/bin/open", "-gj", "/Applications/Example.app"],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)

        let scanner = PropertyListJobScanner(
            locations: [
                LaunchJobScanLocation(
                    directoryURL: directory,
                    domain: .gui(uid: 501),
                    sourceLocation: .userLaunchAgent
                )
            ]
        )

        let jobs = await scanner.scan()
        #expect(jobs.count == 1)
        #expect(jobs.first?.label == "com.example.agent")
        #expect(jobs.first?.programArguments == ["/usr/bin/open", "-gj", "/Applications/Example.app"])
        #expect(jobs.first?.runAtLoad == true)
        #expect(jobs.first?.keepAliveDescription == "SuccessfulExit")
    }

    @Test func loadJobsToleratesDuplicateScannedLabels() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let firstDirectory = root.appendingPathComponent("First", isDirectory: true)
        let secondDirectory = root.appendingPathComponent("Second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let label = "com.example.duplicate"
        try writeLaunchdPlist(label: label, to: firstDirectory.appendingPathComponent("first.plist"))
        try writeLaunchdPlist(label: label, to: secondDirectory.appendingPathComponent("second.plist"))

        let scanner = PropertyListJobScanner(
            locations: [
                LaunchJobScanLocation(
                    directoryURL: firstDirectory,
                    domain: .gui(uid: 501),
                    sourceLocation: .systemLaunchAgent
                ),
                LaunchJobScanLocation(
                    directoryURL: secondDirectory,
                    domain: .gui(uid: 501),
                    sourceLocation: .localLaunchAgent
                )
            ]
        )
        let manager = LiveLaunchdManager(scanner: scanner, domains: [])

        let jobs = try await manager.loadJobs()

        #expect(jobs.map(\.label) == [label])
    }

    @Test func buildsLaunchctlTargetsAndArguments() {
        let job = LaunchJob(
            label: "com.example.daemon",
            domain: .system,
            sourceLocation: .localLaunchDaemon
        )

        #expect(job.domain.serviceTarget(label: job.label) == "system/com.example.daemon")
        #expect(LaunchctlClient.arguments(for: .enable, job: job) == ["enable", "system/com.example.daemon"])
        #expect(LaunchctlClient.arguments(for: .disable, job: job) == ["disable", "system/com.example.daemon"])
        #expect(LaunchctlClient.arguments(for: .kickstart, job: job) == ["kickstart", "system/com.example.daemon"])
        #expect(LaunchctlClient.arguments(for: .restart, job: job) == ["kickstart", "-k", "system/com.example.daemon"])
        #expect(LaunchctlClient.arguments(for: .stop, job: job) == ["kill", "TERM", "system/com.example.daemon"])
        #expect(LaunchctlClient.arguments(for: .copyLabel, job: job).isEmpty)
    }

    @Test func parsesLaunchctlDiagnosticOutputConservatively() {
        let printOutput = """
        gui/501 = {
            services = {
                 123      - 	com.example.running
                   0      1 	com.example.exited
                   0   (pe) 	com.example.pressured
            }
        }
        """
        let disabledOutput = """
        disabled services = {
            "com.example.running" => enabled
            "com.example.exited" => disabled
        }
        """

        let services = LaunchctlOutputParser.parseServices(from: printOutput)
        let disabled = LaunchctlOutputParser.parseDisabledServices(from: disabledOutput)

        #expect(services.first { $0.label == "com.example.running" }?.pid == 123)
        #expect(services.first { $0.label == "com.example.exited" }?.lastExitStatus == 1)
        #expect(disabled["com.example.running"] == false)
        #expect(disabled["com.example.exited"] == true)
    }

    @Test func reportsExitedServicesAsNotRunning() {
        let job = LaunchJob(
            label: "com.example.exited",
            domain: .gui(uid: 501),
            sourceLocation: .localLaunchAgent,
            lastExitStatus: 0
        )

        #expect(job.stateDescription == "Not Running")
        #expect(job.statusDetail == "Last exit 0")
    }

    @Test func mergesLaunchctlStatusIntoScannedJobs() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try writeLaunchdPlist(label: "com.example.running", to: directory.appendingPathComponent("running.plist"))

        let scanner = PropertyListJobScanner(
            locations: [
                LaunchJobScanLocation(
                    directoryURL: directory,
                    domain: .gui(uid: 501),
                    sourceLocation: .userLaunchAgent
                )
            ]
        )
        let launchctl = LaunchctlClient(runner: FakeCommandRunner(responses: [
            "print gui/501": """
            gui/501 = {
                services = {
                     4321      -  com.example.running
                }
            }
            """,
            "print-disabled gui/501": """
            disabled services = {
                "com.example.running" => enabled
            }
            """
        ]))
        let manager = LiveLaunchdManager(scanner: scanner, launchctl: launchctl, domains: [.gui(uid: 501)])

        let jobs = try await manager.loadJobs()

        #expect(jobs.first?.label == "com.example.running")
        #expect(jobs.first?.pid == 4321)
        #expect(jobs.first?.disabled == false)
    }

    @Test func missingLiveDiagnosticDoesNotFailDetailLoading() async throws {
        let job = LaunchJob(
            label: "com.example.missing-service",
            domain: .gui(uid: 501),
            sourceLocation: .localLaunchAgent
        )
        let launchctl = LaunchctlClient(
            runner: FailingCommandRunner(
                result: CommandResult(
                    status: 113,
                    output: "",
                    errorOutput: """
                    Bad request.
                    Could not find service "com.example.missing-service" in domain for user gui: 501
                    """
                )
            )
        )
        let manager = LiveLaunchdManager(launchctl: launchctl, domains: [])

        let detailedJob = try await manager.loadDetails(for: job)

        #expect(detailedJob.label == job.label)
        #expect(detailedJob.rawStatus?.contains("Live launchd diagnostics unavailable") == true)
        #expect(detailedJob.rawStatus?.contains("Could not find service") == true)
    }

    @MainActor
    @Test func routesSystemActionsThroughAdminClient() async {
        let manager = FakeLaunchdManager()
        let admin = FakeAdminClient(status: .enabled)
        let store = LaunchdStore(manager: manager, adminClient: admin)
        await store.refresh()

        let systemJob = LaunchJob(
            label: "com.example.daemon",
            domain: .system,
            sourceLocation: .localLaunchDaemon
        )

        await store.perform(.restart, on: systemJob)

        #expect(manager.performedActions.isEmpty)
        #expect(admin.performedActions == [.restart])
        #expect(admin.performedLabels == ["com.example.daemon"])
    }

    @MainActor
    @Test func blocksSystemActionsUntilHelperIsApproved() async {
        let manager = FakeLaunchdManager()
        let admin = FakeAdminClient(status: .requiresApproval)
        let store = LaunchdStore(manager: manager, adminClient: admin)

        let systemJob = LaunchJob(
            label: "com.example.daemon",
            domain: .system,
            sourceLocation: .localLaunchDaemon
        )

        await store.perform(.disable, on: systemJob)

        #expect(manager.performedActions.isEmpty)
        #expect(admin.performedActions.isEmpty)
        #expect(store.presentedError != nil)
    }

    @MainActor
    @Test func filtersAppleProvidedJobsWhenPreferenceIsDisabled() async {
        let manager = FakeLaunchdManager(
            jobs: [
                LaunchJob(
                    label: "com.apple.example",
                    domain: .gui(uid: 501),
                    sourceLocation: .systemLaunchAgent
                ),
                LaunchJob(
                    label: "com.example.agent",
                    domain: .gui(uid: 501),
                    sourceLocation: .userLaunchAgent
                )
            ]
        )
        let store = LaunchdStore(manager: manager)

        store.includeAppleProvidedJobs = false
        await store.refresh()

        #expect(store.visibleJobs.map(\.label) == ["com.example.agent"])
        #expect(store.filteredJobs.map(\.label) == ["com.example.agent"])
        #expect(store.selectedJob?.label == "com.example.agent")
    }

    @MainActor
    @Test func searchFindsAppleProvidedJobsWhenPreferenceIsDisabled() async {
        let manager = FakeLaunchdManager(
            jobs: [
                LaunchJob(
                    label: "com.apple.locate",
                    domain: .system,
                    plistURL: URL(fileURLWithPath: "/System/Library/LaunchDaemons/com.apple.locate.plist"),
                    sourceLocation: .systemLaunchDaemon,
                    programArguments: ["/usr/libexec/locate.updatedb"]
                ),
                LaunchJob(
                    label: "com.example.agent",
                    domain: .gui(uid: 501),
                    sourceLocation: .userLaunchAgent
                )
            ]
        )
        let store = LaunchdStore(manager: manager)

        store.includeAppleProvidedJobs = false
        store.scope = .domain(.system)
        await store.refresh()
        store.searchText = "locate"

        #expect(store.visibleJobs.map(\.label) == ["com.example.agent"])
        #expect(store.filteredJobs.map(\.label) == ["com.apple.locate"])
        #expect(store.selectedJob?.label == "com.apple.locate")
    }

    @MainActor
    @Test func detailSelectionClearsWhenSearchHasNoMatches() async {
        let manager = FakeLaunchdManager(
            jobs: [
                LaunchJob(
                    label: "com.example.agent",
                    domain: .gui(uid: 501),
                    sourceLocation: .userLaunchAgent
                )
            ]
        )
        let store = LaunchdStore(manager: manager)

        await store.refresh()
        store.searchText = "missing"

        #expect(store.filteredJobs.isEmpty)
        #expect(store.selectedJob == nil)
    }
}

private func writeLaunchdPlist(label: String, to url: URL) throws {
    let plist: [String: Any] = [
        "Label": label,
        "ProgramArguments": ["/usr/bin/true"]
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: url)
}

@MainActor
private final class FakeLaunchdManager: LaunchdManaging, @unchecked Sendable {
    let jobs: [LaunchJob]
    var performedActions: [LaunchAction] = []

    init(jobs: [LaunchJob] = []) {
        self.jobs = jobs
    }

    func loadJobs() async throws -> [LaunchJob] {
        jobs
    }

    func loadDetails(for job: LaunchJob) async throws -> LaunchJob {
        job
    }

    func perform(_ action: LaunchAction, on job: LaunchJob) async throws {
        _ = job
        performedActions.append(action)
    }
}

@MainActor
private final class FakeAdminClient: LaunchdAdministering, @unchecked Sendable {
    var currentStatus: AdminHelperStatus
    var performedActions: [LaunchAction] = []
    var performedLabels: [String] = []

    init(status: AdminHelperStatus) {
        self.currentStatus = status
    }

    func status() -> AdminHelperStatus {
        currentStatus
    }

    func registerHelper() throws -> AdminHelperStatus {
        currentStatus
    }

    func openApprovalSettings() {}

    func performPrivileged(_ action: LaunchAction, on job: LaunchJob) async throws {
        performedActions.append(action)
        performedLabels.append(job.label)
    }
}

private struct FakeCommandRunner: CommandRunning {
    var responses: [String: String]

    func run(_ executableURL: URL, arguments: [String]) async throws -> CommandResult {
        _ = executableURL
        let key = arguments.joined(separator: " ")
        return CommandResult(status: 0, output: responses[key] ?? "", errorOutput: "")
    }
}

private struct FailingCommandRunner: CommandRunning {
    var result: CommandResult

    func run(_ executableURL: URL, arguments: [String]) async throws -> CommandResult {
        throw CommandRunnerError.nonZeroExit(
            executable: executableURL.path,
            arguments: arguments,
            result: result
        )
    }
}
