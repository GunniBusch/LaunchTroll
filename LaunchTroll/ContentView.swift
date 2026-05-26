import SwiftUI

struct ContentView: View {
    @StateObject private var store: LaunchdStore
    @AppStorage(LaunchTrollPreferenceKey.refreshOnLaunch) private var refreshOnLaunch = true
    @AppStorage(LaunchTrollPreferenceKey.includeAppleProvidedJobs) private var includeAppleProvidedJobs = false

    init(store: LaunchdStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } content: {
            JobTableView(store: store)
                .navigationSplitViewColumnWidth(min: 560, ideal: 680)
        } detail: {
            JobDetailView(store: store)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 520)
        }
        .searchable(
            text: $store.searchText,
            placement: .toolbar,
            prompt: "Search Jobs"
        )
        .controlHelp("Search labels, domains, paths, or commands.")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: LaunchAction.refresh.systemImage)
                }
                .disabled(store.isRefreshing)
                .controlHelp(store.isRefreshing ? "Refresh is already in progress." : LaunchAction.refresh.help)
                .accessibilityLabel("Refresh Jobs")
                .accessibilityIdentifier("refreshButton")

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .controlHelp("Refreshing launchd jobs.")
                        .accessibilityLabel("Refreshing Jobs")
                }
            }

            ToolbarSpacer(.fixed)

            ToolbarItemGroup {
                Button {
                    performSelected(.kickstart)
                } label: {
                    Label("Start", systemImage: LaunchAction.kickstart.systemImage)
                }
                .disabled(!store.canPerformSelectedAction)
                .controlHelp(toolbarHelp(for: .kickstart))
                .accessibilityLabel("Start Job")

                Button {
                    performSelected(.restart)
                } label: {
                    Label("Restart", systemImage: LaunchAction.restart.systemImage)
                }
                .disabled(!store.canPerformSelectedAction)
                .controlHelp(toolbarHelp(for: .restart))
                .accessibilityLabel("Restart Job")

                Button {
                    performSelected(.stop)
                } label: {
                    Label("Stop", systemImage: LaunchAction.stop.systemImage)
                }
                .disabled(!store.canPerformSelectedAction)
                .controlHelp(toolbarHelp(for: .stop))
                .accessibilityLabel("Stop Job")
            }

            ToolbarSpacer(.fixed)

            ToolbarItemGroup {
                Button {
                    performSelected(store.selectedJob?.disabled == true ? .enable : .disable)
                } label: {
                    Label(
                        store.selectedJob?.disabled == true ? "Enable" : "Disable",
                        systemImage: store.selectedJob?.disabled == true
                            ? LaunchAction.enable.systemImage
                            : LaunchAction.disable.systemImage
                    )
                }
                .disabled(!store.canPerformSelectedAction)
                .controlHelp(toolbarHelp(for: store.selectedJob?.disabled == true ? .enable : .disable))
                .accessibilityLabel(store.selectedJob?.disabled == true ? "Enable Job" : "Disable Job")

                Menu {
                    Button("Copy Label") {
                        performSelected(.copyLabel)
                    }
                    .disabled(store.selectedJob == nil)
                    .controlHelp(toolbarHelp(for: .copyLabel))

                    Button("Reveal Plist") {
                        performSelected(.revealPlist)
                    }
                    .disabled(store.selectedJob?.plistURL == nil)
                    .controlHelp(toolbarHelp(for: .revealPlist))

                    Divider()

                    Toggle("Show Apple Jobs", isOn: $includeAppleProvidedJobs)
                        .controlHelp("Show launchd jobs from /System/Library and labels beginning with com.apple.")

                    if store.selectedJob?.domain.requiresAdministrator == true, store.helperStatus != .enabled {
                        Divider()

                        Button("Register Privileged Helper") {
                            store.registerHelper()
                        }
                        .controlHelp("Register the privileged helper used for system-domain changes.")

                        Button("Open Login Items Settings") {
                            store.openApprovalSettings()
                        }
                        .controlHelp("Open System Settings to approve the privileged helper.")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
                .controlHelp("Show copy, reveal, and filtering actions.")
                .accessibilityLabel("More Actions")
            }
        }
        .focusedSceneValue(\.launchdCommandActions, commandActions)
        .alert(item: $store.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK")) {
                    store.dismissError()
                }
            )
        }
        .onAppear {
            store.includeAppleProvidedJobs = includeAppleProvidedJobs
        }
        .onChange(of: includeAppleProvidedJobs) { _, newValue in
            store.includeAppleProvidedJobs = newValue
        }
        .task {
            store.includeAppleProvidedJobs = includeAppleProvidedJobs
            guard refreshOnLaunch else {
                return
            }
            await store.refresh()
        }
    }

    private var commandActions: LaunchdCommandActions {
        LaunchdCommandActions {
            Task { await store.refresh() }
        } performSelected: { action in
            performSelected(action)
        } canPerformSelected: { action in
            switch action {
            case .copyLabel:
                return store.selectedJob != nil
            case .revealPlist:
                return store.selectedJob?.plistURL != nil
            case .refresh:
                return true
            default:
                return store.canPerformSelectedAction
            }
        }
    }

    private func performSelected(_ action: LaunchAction) {
        guard let job = store.selectedJob else {
            return
        }
        Task {
            await store.perform(action, on: job)
        }
    }

    private func toolbarHelp(for action: LaunchAction) -> String {
        if store.selectedJob == nil {
            return "Select a launchd job first."
        }
        if store.isPerformingAction {
            return "Wait for the current launchd action to finish."
        }
        if action == .revealPlist, store.selectedJob?.plistURL == nil {
            return "The selected job does not have a plist path."
        }
        return action.help
    }
}

#Preview {
    ContentView(
        store: LaunchdStore(
            manager: FixtureLaunchdManager(),
            adminClient: StaticAdminHelperClient(helperStatus: .requiresApproval)
        )
    )
}
