import AppKit
import Combine
import Foundation

@MainActor
final class LaunchdStore: ObservableObject {
    @Published private(set) var jobs: [LaunchJob] = []
    @Published var selectedJobID: LaunchJob.ID?
    @Published var scope: JobScope = .all {
        didSet {
            updateSelection()
        }
    }
    @Published var searchText = "" {
        didSet {
            updateSelection()
        }
    }
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPerformingAction = false
    @Published var presentedError: LaunchdStoreError?
    @Published private(set) var helperStatus: AdminHelperStatus
    @Published var includeAppleProvidedJobs = false {
        didSet {
            updateSelection()
        }
    }

    private let manager: LaunchdManaging
    private let adminClient: LaunchdAdministering

    init() {
        self.manager = LiveLaunchdManager()
        self.adminClient = SMAppServiceAdminClient()
        self.helperStatus = adminClient.status()
    }

    init(manager: LaunchdManaging) {
        self.manager = manager
        self.adminClient = StaticAdminHelperClient(helperStatus: .requiresApproval)
        self.helperStatus = adminClient.status()
    }

    init(manager: LaunchdManaging, adminClient: LaunchdAdministering) {
        self.manager = manager
        self.adminClient = adminClient
        self.helperStatus = adminClient.status()
    }

    var filteredJobs: [LaunchJob] {
        searchBaseJobs
            .filter(matchesScope)
            .filter(matchesSearch)
    }

    var visibleJobs: [LaunchJob] {
        jobs.filter(matchesVisibility)
    }

    var selectedJob: LaunchJob? {
        guard let selectedJobID else {
            return nil
        }
        return filteredJobs.first { $0.id == selectedJobID }
    }

    var canPerformSelectedAction: Bool {
        selectedJob != nil && !isPerformingAction
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            helperStatus = adminClient.status()
            jobs = try await manager.loadJobDefinitions()
            updateSelection()

            jobs = try await manager.loadJobs()
            updateSelection()
        } catch {
            present(error)
        }
    }

    func loadDetailsForSelection() async {
        guard let selectedJob else {
            return
        }

        do {
            let detailedJob = try await manager.loadDetails(for: selectedJob)
            replace(detailedJob)
        } catch {
            present(error)
        }
    }

    func perform(_ action: LaunchAction, on job: LaunchJob) async {
        switch action {
        case .refresh:
            await refresh()
            return
        case .revealPlist:
            reveal(job)
            return
        case .copyLabel:
            copyLabel(job)
            return
        default:
            break
        }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            if job.domain.requiresAdministrator {
                try await performPrivileged(action, on: job)
            } else {
                try await manager.perform(action, on: job)
            }
            await refresh()
        } catch {
            present(error)
            helperStatus = adminClient.status()
        }
    }

    func registerHelper() {
        do {
            helperStatus = try adminClient.registerHelper()
        } catch {
            present(error)
            helperStatus = adminClient.status()
        }
    }

    func openApprovalSettings() {
        adminClient.openApprovalSettings()
    }

    func dismissError() {
        presentedError = nil
    }

    private func performPrivileged(_ action: LaunchAction, on job: LaunchJob) async throws {
        helperStatus = adminClient.status()

        if helperStatus == .notRegistered || helperStatus == .notFound {
            helperStatus = try adminClient.registerHelper()
        }

        guard helperStatus == .enabled else {
            throw AdminHelperError.helperUnavailable(helperStatus)
        }

        try await adminClient.performPrivileged(action, on: job)
    }

    private func reveal(_ job: LaunchJob) {
        guard let plistURL = job.plistURL else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([plistURL])
    }

    private func copyLabel(_ job: LaunchJob) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(job.label, forType: .string)
    }

    private func replace(_ job: LaunchJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else {
            return
        }
        jobs[index] = job
    }

    private func present(_ error: Error) {
        presentedError = LaunchdStoreError(error)
    }

    private func updateSelection() {
        if selectedJobID == nil || !filteredJobs.contains(where: { $0.id == selectedJobID }) {
            selectedJobID = filteredJobs.first?.id
        }
    }

    private func matchesVisibility(_ job: LaunchJob) -> Bool {
        includeAppleProvidedJobs || !job.isAppleProvided
    }

    private var searchBaseJobs: [LaunchJob] {
        isSearching ? jobs : visibleJobs
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private func matchesScope(_ job: LaunchJob) -> Bool {
        switch scope {
        case .all:
            return true
        case .domain(let domain):
            return job.domain == domain
        case .running:
            return job.isRunning
        case .disabled:
            return job.disabled == true
        case .needsAdmin:
            return job.domain.requiresAdministrator
        }
    }

    private func matchesSearch(_ job: LaunchJob) -> Bool {
        let query = trimmedSearchText
        guard !query.isEmpty else {
            return true
        }

        return job.label.localizedCaseInsensitiveContains(query)
            || job.domain.displayName.localizedCaseInsensitiveContains(query)
            || job.sourceLocation.displayName.localizedCaseInsensitiveContains(query)
            || (job.program?.localizedCaseInsensitiveContains(query) ?? false)
            || job.programArguments.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LaunchdStoreError: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ error: Error) {
        self.title = "Launchd Operation Failed"
        self.message = error.localizedDescription
    }
}
