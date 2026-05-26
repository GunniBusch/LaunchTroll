import SwiftUI

struct JobTableView: View {
    @ObservedObject var store: LaunchdStore

    var body: some View {
        Group {
            if store.jobs.isEmpty, store.isRefreshing {
                ProgressView("Loading Jobs")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.filteredJobs.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: emptyImage, description: Text(emptyDescription))
            } else {
                Table(store.filteredJobs, selection: $store.selectedJobID) {
                    TableColumn("Label", value: \.label)

                    TableColumn("Domain") { job in
                        Label(job.domain.displayName, systemImage: job.domain.systemImage)
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("State") { job in
                        Label(job.stateDescription, systemImage: imageName(for: job))
                            .foregroundStyle(foregroundStyle(for: job))
                    }
                    .width(min: 95, ideal: 115)

                    TableColumn("PID") { job in
                        if let pid = job.pid {
                            Text(String(pid))
                                .monospacedDigit()
                        } else {
                            Text("-")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 60, ideal: 70, max: 90)
                }
                .contextMenu {
                    if let job = store.selectedJob {
                        Button("Copy Label") {
                            Task { await store.perform(.copyLabel, on: job) }
                        }
                        .controlHelp(LaunchAction.copyLabel.help)

                        Button("Reveal Plist") {
                            Task { await store.perform(.revealPlist, on: job) }
                        }
                        .disabled(job.plistURL == nil)
                        .controlHelp(LaunchAction.revealPlist.help)

                        Divider()

                        Button("Start") {
                            Task { await store.perform(.kickstart, on: job) }
                        }
                        .disabled(store.isPerformingAction)
                        .controlHelp(LaunchAction.kickstart.help)

                        Button("Restart") {
                            Task { await store.perform(.restart, on: job) }
                        }
                        .disabled(store.isPerformingAction)
                        .controlHelp(LaunchAction.restart.help)

                        Button("Stop") {
                            Task { await store.perform(.stop, on: job) }
                        }
                        .disabled(store.isPerformingAction)
                        .controlHelp(LaunchAction.stop.help)
                    }
                }
            }
        }
        .navigationTitle(store.scope.title)
    }

    private var emptyTitle: String {
        store.jobs.isEmpty ? "No Jobs" : "No Results"
    }

    private var emptyImage: String {
        store.jobs.isEmpty ? "list.bullet.rectangle" : "magnifyingglass"
    }

    private var emptyDescription: String {
        if store.jobs.isEmpty {
            return "No launchd plists were found in the scanned locations."
        }

        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return "No jobs match \"\(query)\"."
        }

        return "No jobs match the selected sidebar filter."
    }

    private func imageName(for job: LaunchJob) -> String {
        if job.disabled == true {
            return "slash.circle"
        }
        if job.isRunning {
            return "play.circle.fill"
        }
        return "circle"
    }

    private func foregroundStyle(for job: LaunchJob) -> Color {
        if job.disabled == true {
            return .secondary
        }
        if job.isRunning {
            return .green
        }
        return .secondary
    }
}
