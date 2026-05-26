import SwiftUI

struct JobDetailView: View {
    @ObservedObject var store: LaunchdStore

    var body: some View {
        Group {
            if let job = store.selectedJob {
                Form {
                    Section("Status") {
                        LabeledContent("Label", value: job.label)
                        LabeledContent("Domain", value: job.domain.displayName)
                        LabeledContent("State", value: job.stateDescription)
                        if let pid = job.pid {
                            LabeledContent("PID", value: String(pid))
                        }
                        if let lastExitStatus = job.lastExitStatus {
                            LabeledContent("Last Exit", value: lastExitStatus.formatted())
                        }
                        LabeledContent("Needs Admin", value: job.domain.requiresAdministrator ? "Yes" : "No")
                    }

                    Section("Definition") {
                        LabeledContent("Source", value: job.sourceLocation.displayName)
                        if let plistURL = job.plistURL {
                            LabeledContent("Plist") {
                                Text(plistURL.path)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                        }
                        if let program = job.program {
                            LabeledContent("Program", value: program)
                        }
                        if !job.programArguments.isEmpty {
                            LabeledContent("Arguments") {
                                Text(job.programArguments.joined(separator: " "))
                                    .lineLimit(3)
                                    .truncationMode(.middle)
                            }
                        }
                        if let keepAliveDescription = job.keepAliveDescription {
                            LabeledContent("Keep Alive", value: keepAliveDescription)
                        }
                        if let runAtLoad = job.runAtLoad {
                            LabeledContent("Run At Load", value: runAtLoad ? "Yes" : "No")
                        }
                    }

                    if let rawStatus = job.rawStatus, !rawStatus.isEmpty {
                        Section("Diagnostics") {
                            Text(rawStatus)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if job.domain.requiresAdministrator, store.helperStatus != .enabled {
                        AdminHelperView(store: store)
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Details")
                .task(id: job.id) {
                    await store.loadDetailsForSelection()
                }
            } else {
                ContentUnavailableView(
                    store.isRefreshing ? "Loading Jobs" : "No Job Selected",
                    systemImage: store.isRefreshing ? "arrow.clockwise" : "sidebar.right",
                    description: Text(store.isRefreshing ? "Reading launchd plists." : "Select a launchd job to inspect it.")
                )
            }
        }
    }
}
