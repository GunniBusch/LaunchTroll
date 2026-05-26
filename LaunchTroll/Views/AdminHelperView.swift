import SwiftUI

struct AdminHelperView: View {
    @ObservedObject var store: LaunchdStore

    var body: some View {
        Section("Privileged Helper") {
            LabeledContent("Status", value: store.helperStatus.rawValue)
            Text(store.helperStatus.detail)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    store.registerHelper()
                } label: {
                    Label("Register Helper", systemImage: "lock.shield")
                }
                .disabled(store.helperStatus == .enabled)
                .controlHelp("Register the privileged helper used for system-domain changes.")

                Button {
                    store.openApprovalSettings()
                } label: {
                    Label("Open Login Items", systemImage: "gear")
                }
                .disabled(store.helperStatus == .enabled)
                .controlHelp("Open System Settings to approve the privileged helper.")
            }
            .controlSize(.small)
        }
    }
}
