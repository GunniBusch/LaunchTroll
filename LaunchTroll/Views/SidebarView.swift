import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: LaunchdStore

    var body: some View {
        List(selection: $store.scope) {
            Section("Jobs") {
                SidebarRow(scope: .all, count: store.visibleJobs.count)
                SidebarRow(scope: .running, count: store.visibleJobs.filter(\.isRunning).count)
                SidebarRow(scope: .disabled, count: store.visibleJobs.filter { $0.disabled == true }.count)
                SidebarRow(scope: .needsAdmin, count: store.visibleJobs.filter { $0.domain.requiresAdministrator }.count)
            }

            Section("Domains") {
                ForEach(LaunchDomain.currentUserDomains) { domain in
                    SidebarRow(
                        scope: .domain(domain),
                        count: store.visibleJobs.filter { $0.domain == domain }.count
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("LaunchTroll")
    }
}

private struct SidebarRow: View {
    var scope: JobScope
    var count: Int

    var body: some View {
        Label {
            HStack {
                Text(scope.title)
                Spacer()
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: scope.systemImage)
        }
        .tag(scope)
        .controlHelp(scope.help)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scope.title), \(count) \(count == 1 ? "job" : "jobs")")
    }
}
