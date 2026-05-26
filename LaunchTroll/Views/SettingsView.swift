import SwiftUI

struct SettingsView: View {
    @AppStorage(LaunchTrollPreferenceKey.refreshOnLaunch) private var refreshOnLaunch = true
    @AppStorage(LaunchTrollPreferenceKey.includeAppleProvidedJobs) private var includeAppleProvidedJobs = false
    @State private var helperStatus: AdminHelperStatus = .notRegistered
    @State private var helperError: SettingsError?

    private let adminClient = SMAppServiceAdminClient()

    var body: some View {
        Form {
            Section("Jobs") {
                Toggle("Refresh when opening a window", isOn: $refreshOnLaunch)
                    .controlHelp("Refresh launchd jobs automatically when a LaunchTroll window opens.")

                Toggle("Include Apple-provided jobs", isOn: $includeAppleProvidedJobs)
                    .controlHelp("Show jobs from /System/Library and labels beginning with com.apple.")
            }

            Section("Signing") {
                LabeledContent("App Sandbox", value: "Off")
                LabeledContent("Hardened Runtime", value: "On")
            }

            Section("Privileged Helper") {
                LabeledContent("Status", value: helperStatus.rawValue)
                Text(helperStatus.detail)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        registerHelper()
                    } label: {
                        Label("Register Helper", systemImage: "lock.shield")
                    }
                    .disabled(helperStatus == .enabled)
                    .controlHelp("Register the privileged helper used for system-domain launchd changes.")

                    Button {
                        refreshHelperStatus()
                    } label: {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                    }
                    .controlHelp("Refresh the privileged helper registration status.")

                    Button {
                        adminClient.openApprovalSettings()
                    } label: {
                        Label("Open Login Items", systemImage: "gear")
                    }
                    .disabled(helperStatus == .enabled)
                    .controlHelp("Open System Settings to approve the privileged helper.")
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
        .task {
            refreshHelperStatus()
        }
        .alert(item: $helperError) { error in
            Alert(
                title: Text("Helper Registration Failed"),
                message: Text(error.message),
                dismissButton: .default(Text("OK")) {
                    helperError = nil
                }
            )
        }
    }

    private func refreshHelperStatus() {
        helperStatus = adminClient.status()
    }

    private func registerHelper() {
        do {
            helperStatus = try adminClient.registerHelper()
        } catch {
            helperError = SettingsError(error)
            refreshHelperStatus()
        }
    }
}

#Preview {
    SettingsView()
}

private struct SettingsError: Identifiable {
    let id = UUID()
    let message: String

    init(_ error: Error) {
        self.message = error.localizedDescription
    }
}
